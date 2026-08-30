import {FilesetResolver, HandLandmarker, PoseLandmarker} from './vision_bundle.mjs';

let visionPromise;
let landmarkerPromise;
let handLandmarkerPromise;
const sessions = new WeakMap();

async function getLandmarker() {
  visionPromise ??= FilesetResolver.forVisionTasks('./mediapipe/wasm');
  const vision = await visionPromise;
  landmarkerPromise ??= PoseLandmarker.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath: './assets/assets/models/pose_lite.task',
      delegate: 'GPU',
    },
    runningMode: 'VIDEO',
    numPoses: 1,
    minPoseDetectionConfidence: 0.5,
    minPosePresenceConfidence: 0.5,
    minTrackingConfidence: 0.5,
  }).catch(() => PoseLandmarker.createFromOptions(vision, {
    baseOptions: {modelAssetPath: './assets/assets/models/pose_lite.task'},
    runningMode: 'VIDEO',
    numPoses: 1,
    minPoseDetectionConfidence: 0.5,
    minPosePresenceConfidence: 0.5,
    minTrackingConfidence: 0.5,
  }));
  return landmarkerPromise;
}

async function getHandLandmarker() {
  visionPromise ??= FilesetResolver.forVisionTasks('./mediapipe/wasm');
  const vision = await visionPromise;
  handLandmarkerPromise ??= HandLandmarker.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath: './assets/assets/models/hand.task',
      delegate: 'GPU',
    },
    runningMode: 'VIDEO',
    numHands: 2,
    minHandDetectionConfidence: 0.35,
    minHandPresenceConfidence: 0.35,
    minTrackingConfidence: 0.35,
  }).catch(() => HandLandmarker.createFromOptions(vision, {
    baseOptions: {modelAssetPath: './assets/assets/models/hand.task'},
    runningMode: 'VIDEO',
    numHands: 2,
    minHandDetectionConfidence: 0.35,
    minHandPresenceConfidence: 0.35,
    minTrackingConfidence: 0.35,
  }));
  return handLandmarkerPromise;
}

function angle(a, b, c, width, height) {
  const v1x = (a.x - b.x) * width;
  const v1y = (a.y - b.y) * height;
  const v2x = (c.x - b.x) * width;
  const v2y = (c.y - b.y) * height;
  const n1 = Math.hypot(v1x, v1y);
  const n2 = Math.hypot(v2x, v2y);
  if (n1 < 1e-6 || n2 < 1e-6) return NaN;
  const cosine = Math.max(-1, Math.min(1,
      (v1x * v2x + v1y * v2y) / (n1 * n2)));
  return Math.acos(cosine) * 180 / Math.PI;
}

function fingerCurl(hand, ids, width, height) {
  const points = [hand[0], ...ids.map((id) => hand[id])];
  let total = 0;
  for (let index = 0; index < points.length - 2; index++) {
    const value = angle(points[index], points[index + 1],
        points[index + 2], width, height);
    if (!Number.isFinite(value)) return NaN;
    total += 180 - value;
  }
  return total;
}

function featuresForHand(hand, width, height) {
  return {
    curl_thumb: fingerCurl(hand, [1, 2, 3, 4], width, height),
    curl_index: fingerCurl(hand, [5, 6, 7, 8], width, height),
    curl_middle: fingerCurl(hand, [9, 10, 11, 12], width, height),
    curl_ring: fingerCurl(hand, [13, 14, 15, 16], width, height),
    curl_pinky: fingerCurl(hand, [17, 18, 19, 20], width, height),
    hand_spread: angle(hand[5], hand[0], hand[17], width, height),
  };
}

function collectHandFeatures(result, width, height) {
  const output = {};
  const frames = [];
  const hands = result.landmarks ?? [];
  const assign = (features, suffix) => {
    for (const [name, value] of Object.entries(features)) {
      if (Number.isFinite(value)) output[`${name}_${suffix}`] = value;
    }
  };
  hands.forEach((hand, index) => {
    const features = featuresForHand(hand, width, height);
    const category = result.handedness?.[index]?.[0];
    const label = category?.categoryName ?? category?.displayName ?? '';
    const suffix = label.toLowerCase().startsWith('left') ? 'L' : 'R';
    assign(features, suffix);
    frames.push({side: suffix, landmarks: hand});
    // Satu tangan sering tertukar karena kamera depan dicerminkan. Menyalin
    // sinyal ke dua sisi membuat recipe unilateral tetap robust; saat dua
    // tangan terlihat, handedness tetap membedakan keduanya.
    if (hands.length === 1) assign(features, suffix === 'L' ? 'R' : 'L');
  });
  return {features: output, hands: frames};
}

async function start(video, enableHands, onResult) {
  if (sessions.has(video)) return;
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Browser tidak mendukung akses kamera.');
  }
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      facingMode: 'user',
      width: {ideal: 1280},
      height: {ideal: 720},
    },
    audio: false,
  });
  video.srcObject = stream;
  await video.play();
  const landmarker = await getLandmarker();
  const handLandmarker = enableHands ? await getHandLandmarker() : null;
  const session = {
    active: true,
    frameId: 0,
    lastVideoTime: -1,
    lastRun: 0,
    recorder: null,
    recordedChunks: [],
  };
  sessions.set(video, session);

  const loop = () => {
    if (!session.active) return;
    session.frameId = requestAnimationFrame(loop);
    const now = performance.now();
    if (now - session.lastRun < 66 ||
        video.currentTime === session.lastVideoTime ||
        video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return;
    session.lastRun = now;
    session.lastVideoTime = video.currentTime;
    try {
      const result = landmarker.detectForVideo(video, now);
      const handResult = handLandmarker
          ? handLandmarker.detectForVideo(video, now)
          : {landmarks: []};
      const landmarks = result.landmarks?.[0] ?? Array.from(
          {length: 33}, () => ({x: 0, y: 0, visibility: 0}));
      const handData = collectHandFeatures(
          handResult, video.videoWidth, video.videoHeight);
      onResult(JSON.stringify({
        landmarks,
        handFeatures: handData.features,
        hands: handData.hands,
        width: video.videoWidth,
        height: video.videoHeight,
        timestamp: Math.round(now),
      }));
    } catch (error) {
      console.error('Motorix pose frame gagal', error);
    }
  };
  session.frameId = requestAnimationFrame(loop);
}

function startRecording(video) {
  const session = sessions.get(video);
  const stream = video.srcObject;
  if (!session || !stream) throw new Error('Kamera belum siap.');
  if (session.recorder?.state === 'recording') return;
  const mimeType = [
    'video/webm;codecs=vp9',
    'video/webm;codecs=vp8',
    'video/webm',
  ].find((type) => MediaRecorder.isTypeSupported(type));
  const recorder = new MediaRecorder(stream, mimeType ? {mimeType} : {});
  session.recordedChunks = [];
  recorder.ondataavailable = (event) => {
    if (event.data.size) session.recordedChunks.push(event.data);
  };
  recorder.start(250);
  session.recorder = recorder;
}

async function stopRecording(video) {
  const session = sessions.get(video);
  const recorder = session?.recorder;
  if (!recorder) throw new Error('Perekaman belum dimulai.');
  if (recorder.state !== 'inactive') {
    await new Promise((resolve, reject) => {
      recorder.addEventListener('stop', resolve, {once: true});
      recorder.addEventListener('error', () => reject(recorder.error),
          {once: true});
      recorder.stop();
    });
  }
  const mimeType = recorder.mimeType || 'video/webm';
  const blob = new Blob(session.recordedChunks, {type: mimeType});
  session.recorder = null;
  session.recordedChunks = [];
  return {bytes: new Uint8Array(await blob.arrayBuffer()), mimeType};
}

function stop(video) {
  const session = sessions.get(video);
  if (session) {
    if (session.recorder?.state === 'recording') session.recorder.stop();
    session.active = false;
    cancelAnimationFrame(session.frameId);
    sessions.delete(video);
  }
  const stream = video.srcObject;
  if (stream) stream.getTracks().forEach((track) => track.stop());
  video.srcObject = null;
}

globalThis.motorixPose = {start, stop, startRecording, stopRecording};
