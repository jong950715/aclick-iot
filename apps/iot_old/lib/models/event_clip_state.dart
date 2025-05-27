import 'dart:async';
import 'package:flutter/services.dart';

/// sealed class 로 정의한 상태들
sealed class EventClipState {
  const EventClipState();
}
class Idle            extends EventClipState { const Idle(); }
class WaitingSegments extends EventClipState { const WaitingSegments(); }
class CreatingClip   extends EventClipState { const CreatingClip(); }
class ClipCreated    extends EventClipState { final String uri; const ClipCreated(this.uri); }
class UploadPending  extends EventClipState { final String uri; const UploadPending(this.uri); }
class Uploading      extends EventClipState { final String uri; const Uploading(this.uri); }
class UploadSuccess  extends EventClipState { final String uri; const UploadSuccess(this.uri); }
class Failure        extends EventClipState { final String message; const Failure(this.message); }
