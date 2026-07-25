import * as admin from "firebase-admin";
import * as apn from "apn";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";

admin.initializeApp();

const apnsKey = defineSecret("APNS_AUTH_KEY");
const apnsKeyID = defineSecret("APNS_KEY_ID");
const apnsTeamID = defineSecret("APNS_TEAM_ID");

const bundleID = "com.Manrai.Ziggy";
const region = "asia-south1";
const secrets = [apnsKey, apnsKeyID, apnsTeamID];

type WidgetEvent = {
  title?: string;
  sender?: string;
  senderDeviceID?: string;
  type?: string;
  emotion?: string;
};

type GameState = {
  leftPlayer?: string;
  rightPlayer?: string;
  hostName?: string;
  guestName?: string;
  status?: string;
};

type DeviceRecord = {
  deviceID?: string;
  token?: string;
  username?: string;
};

// A one-tap message, love note, or feed/play/hug activity -> partner widget.
export const notifyPartnerWidget = onDocumentCreated(
  {
    document: "relationships/{relationshipId}/emotions/{emotionId}",
    region,
    secrets,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const relationshipId = event.params.relationshipId;
    const emotionId = event.params.emotionId;
    const data = snapshot.data() as WidgetEvent;

    if (!data.title || !data.sender) {
      logger.info("Skipping widget push without title/sender", {
        relationshipId,
        emotionId,
      });
      return;
    }

    await sendPartnerWidgetPush(relationshipId, emotionId, data);
  }
);

// A sent Instant -> partner widget. The meta doc has a fixed id and is
// overwritten on every send, so we listen for writes (not just creates).
export const notifyPartnerInstant = onDocumentWritten(
  {
    document: "relationships/{relationshipId}/data/instant_meta",
    region,
    secrets,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) {
      // Document was deleted (e.g. account data wipe) — nothing to send.
      return;
    }

    const relationshipId = event.params.relationshipId;
    const data = after.data() as {
      sender?: string;
      senderDeviceID?: string;
      sentAt?: admin.firestore.Timestamp;
    };

    if (!data.sender) {
      logger.info("Skipping instant push without sender", {relationshipId});
      return;
    }

    const eventID = data.sentAt ?
      String(data.sentAt.toMillis()) :
      String(Date.now());

    await sendPartnerWidgetPush(relationshipId, eventID, {
      title: "Instant 📸",
      sender: data.sender,
      senderDeviceID: data.senderDeviceID,
      type: "instant",
      emotion: "",
    });
  }
);

// A sent doodle -> partner widget. Like the instant, the meta doc has a fixed
// id and is overwritten each send, so we listen for writes (not just creates).
export const notifyPartnerDoodle = onDocumentWritten(
  {
    document: "relationships/{relationshipId}/data/doodle_meta",
    region,
    secrets,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) {
      return;
    }

    const relationshipId = event.params.relationshipId;
    const data = after.data() as {
      sender?: string;
      senderDeviceID?: string;
      sentAt?: admin.firestore.Timestamp;
    };

    if (!data.sender) {
      logger.info("Skipping doodle push without sender", {relationshipId});
      return;
    }

    const eventID = data.sentAt ?
      String(data.sentAt.toMillis()) :
      String(Date.now());

    await sendPartnerWidgetPush(relationshipId, eventID, {
      title: "Doodle 🎨",
      sender: data.sender,
      senderDeviceID: data.senderDeviceID,
      type: "doodle",
      emotion: "",
    });
  }
);

// When one partner opens a game lobby first, invite the other partner to join.
export const notifyPartnerGameInvite = onDocumentWritten(
  {
    document: "relationships/{relationshipId}/games/{gameId}",
    region,
    secrets,
  },
  async (event) => {
    const before = event.data?.before?.data() as GameState | undefined;
    const after = event.data?.after?.data() as GameState | undefined;
    if (!after) {
      return;
    }

    const relationshipId = event.params.relationshipId;
    const gameId = event.params.gameId;
    const sender = gameInviteSender(before, after, gameId);
    if (!sender) {
      return;
    }

    await sendPartnerWidgetPush(
      relationshipId,
      `${gameId}-${Date.now()}`,
      {
        title: `gameInvite:${gameId}`,
        sender,
        type: "gameInvite",
        emotion: gameId,
      }
    );
  }
);

// Shared: look up the partner's device(s) and deliver the background push.
async function sendPartnerWidgetPush(
  relationshipId: string,
  eventID: string,
  data: WidgetEvent
): Promise<void> {
  const devices = await admin
    .firestore()
    .collection("relationships")
    .doc(relationshipId)
    .collection("devices")
    .get();

  const tokens = devices.docs
    .map((doc) => doc.data() as DeviceRecord)
    .filter((device) => {
      if (!device.token) {
        return false;
      }

      if (data.senderDeviceID) {
        return device.deviceID !== data.senderDeviceID;
      }

      return device.username !== data.sender;
    })
    .map((device) => device.token as string);

  if (tokens.length === 0) {
    logger.info("No partner device token found for widget push", {
      relationshipId,
      eventID,
    });
    return;
  }

  const productionProvider = new apn.Provider({
    token: {
      key: apnsKey.value(),
      keyId: apnsKeyID.value(),
      teamId: apnsTeamID.value(),
    },
    production: true,
  });

  const sandboxProvider = new apn.Provider({
    token: {
      key: apnsKey.value(),
      keyId: apnsKeyID.value(),
      teamId: apnsTeamID.value(),
    },
    production: false,
  });

  try {
    const alertNotification = createWidgetNotification(
      relationshipId,
      eventID,
      data,
      true
    );
    const backgroundNotification = createWidgetNotification(
      relationshipId,
      eventID,
      data,
      false
    );

    // Xcode installs use sandbox APNs tokens. App Store installs use
    // production APNs tokens. Sending to both lets the same function support
    // local testing and the released app; APNs rejects the wrong environment.
    //
    // We send one visible alert plus one silent background signal. The silent
    // signal is what gives the app a chance to cache big assets like doodles
    // into the App Group so WidgetKit can render them.
    const [
      productionAlertResponse,
      sandboxAlertResponse,
      productionBackgroundResponse,
      sandboxBackgroundResponse,
    ] = await Promise.all([
      productionProvider.send(alertNotification, tokens),
      sandboxProvider.send(alertNotification, tokens),
      productionProvider.send(backgroundNotification, tokens),
      sandboxProvider.send(backgroundNotification, tokens),
    ]);

    const failed = [
      ...productionAlertResponse.failed,
      ...sandboxAlertResponse.failed,
      ...productionBackgroundResponse.failed,
      ...sandboxBackgroundResponse.failed,
    ];
    failed.forEach((failure: any) => {
      logger.warn("APNs widget push failed", {
        relationshipId,
        eventID,
        device: failure.device,
        status: failure.status,
        response: failure.response,
      });
    });

    logger.info("Sent partner widget push", {
      relationshipId,
      eventID,
      productionAlertSent: productionAlertResponse.sent.length,
      sandboxAlertSent: sandboxAlertResponse.sent.length,
      productionBackgroundSent: productionBackgroundResponse.sent.length,
      sandboxBackgroundSent: sandboxBackgroundResponse.sent.length,
      failed: failed.length,
    });
  } finally {
    productionProvider.shutdown();
    sandboxProvider.shutdown();
  }
}

function createWidgetNotification(
  relationshipId: string,
  eventID: string,
  data: WidgetEvent,
  visible: boolean
): any {
  const notification = new apn.Notification();
  notification.topic = bundleID;
  notification.expiry = Math.floor(Date.now() / 1000) + 30 * 60;
  notification.contentAvailable = true;
  notification.threadId = "ziggy-partner-updates";

  if (visible) {
    const alert = notificationAlert(data);
    notification.pushType = "alert";
    notification.priority = 10;
    notification.alert = {
      title: alert.title,
      body: alert.body,
    };
    notification.sound = "default";
  } else {
    notification.pushType = "background";
    notification.priority = 5;
  }

  notification.payload = {
    relationshipCode: relationshipId,
    eventID: eventID,
    title: data.title,
    sender: data.sender,
    type: data.type ?? "love",
    emotion: data.emotion ?? "",
  };

  return notification;
}

function notificationAlert(data: WidgetEvent): {title: string; body: string} {
  const sender = data.sender ?? "Your partner";
  const title = data.title ?? "";
  const type = data.type ?? "love";

  if (type === "instant") {
    return {
      title: "Ziggy got you an Instant",
      body: `${sender} sent you a tiny moment. Tap to peek.`,
    };
  }

  if (type === "doodle") {
    return {
      title: "A little doodle appeared",
      body: `${sender} drew you something. Check your Home Screen 🎨`,
    };
  }

  if (type === "gameInvite") {
    return {
      title: "Ziggy wants game time",
      body: `${sender} is inviting you to play ${gameName(data.emotion)}.`,
    };
  }

  if (type === "activity") {
    if (title.includes("fed")) {
      return {
        title: "Ziggy just got fed",
        body: `${sender} fed me. I am doing my happy little dance.`,
      };
    }

    if (title.includes("played")) {
      return {
        title: "Ziggy loves playtime",
        body: `${sender} played with me — I love it when we play together! 🎮💕`,
      };
    }

    if (title.includes("pizza")) {
      return {
        title: "Pizza party for Ziggy",
        body: `${sender} made me pizza and I am very serious about it.`,
      };
    }

    if (title.includes("hug")) {
      return {
        title: "Ziggy got a hug",
        body: `${sender} gave me a hug. I saved some warmth for you.`,
      };
    }
  }

  if (title.startsWith("custom:")) {
    const note = title.replace("custom:", "").trim();
    return {
      title: `${sender} sent you a Ziggy note`,
      body: note || "Tap to see the little message.",
    };
  }

  if (title.includes("missing")) {
    return {
      title: "Someone misses you",
      body: `${sender} says Ziggy is feeling extra clingy today.`,
    };
  }

  if (title.includes("good night")) {
    return {
      title: "A tiny good night",
      body: `${sender} and Ziggy want you to sleep well.`,
    };
  }

  if (title.includes("good morning")) {
    return {
      title: "Good morning from Ziggy",
      body: `${sender} sent you a soft start to the day.`,
    };
  }

  if (title.includes("proud")) {
    return {
      title: "Ziggy is proud of you",
      body: `${sender} wanted you to know that too.`,
    };
  }

  return {
    title: "Ziggy has something for you",
    body: `${sender} sent a little love your way.`,
  };
}

function gameInviteSender(
  before: GameState | undefined,
  after: GameState,
  gameId: string
): string | undefined {
  if (gameId === "airHockey") {
    const beforeHost = before?.hostName ?? "";
    const afterHost = after.hostName ?? "";
    const afterGuest = after.guestName ?? "";
    if (!beforeHost && afterHost && !afterGuest) {
      return afterHost;
    }
    return undefined;
  }

  const beforeLeft = before?.leftPlayer ?? "";
  const afterLeft = after.leftPlayer ?? "";
  const afterRight = after.rightPlayer ?? "";

  if (!beforeLeft && afterLeft && !afterRight) {
    return afterLeft;
  }

  return undefined;
}

function gameName(gameId?: string): string {
  switch (gameId) {
  case "traceDrawing":
    return "Trace Together";
  case "pizzaKitchen":
    return "Pizza Kitchen";
  case "airHockey":
    return "Air Hockey";
  case "ticTacToe":
    return "Tic Tac Toe";
  case "dotsAndBoxes":
    return "Dots and Boxes";
  default:
    return "with Ziggy";
  }
}
