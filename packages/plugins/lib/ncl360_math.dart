import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

enum PinType {
  environment,
  camera,
  scene;

  static PinType fromString(String? val) {
    if (val == null) return PinType.environment;
    final lower = val.toLowerCase().trim();
    if (lower == 'camera') return PinType.camera;
    if (lower == 'scene') return PinType.scene;
    return PinType.environment;
  }
}

class SphericalCoordinate {
  final double polar;
  final double azimuthal;
  final double radius;
  final PinType pin;

  const SphericalCoordinate({
    this.polar = 0.0,
    this.azimuthal = 0.0,
    this.radius = 1.0,
    this.pin = PinType.environment,
  });

  static double normalizeDegrees(double degrees) {
    final norm = degrees % 360.0;
    final result = norm < 0 ? norm + 360.0 : norm;
    return result == 360.0 ? 0.0 : (result == -0.0 ? 0.0 : result);
  }

  static double deltaAngleDegrees(double from, double to) {
    double diff = (to - from) % 360.0;
    if (diff > 180.0) {
      diff -= 360.0;
    } else if (diff < -180.0) {
      diff += 360.0;
    }
    return diff;
  }

  double angularDistanceTo(double targetAzimuthal, double targetPolar) {
    final az1 = azimuthal * math.pi / 180.0;
    final el1 = polar * math.pi / 180.0;
    final az2 = targetAzimuthal * math.pi / 180.0;
    final el2 = targetPolar * math.pi / 180.0;

    final deltaAz = az2 - az1;
    final cosAngle = (math.sin(el1) * math.sin(el2)) +
        (math.cos(el1) * math.cos(el2) * math.cos(deltaAz));
    final clampedCos = cosAngle.clamp(-1.0, 1.0);
    return math.acos(clampedCos) * 180.0 / math.pi;
  }

  bool isInView({
    required double cameraYaw,
    required double cameraPitch,
    required double fov,
    double marginDegrees = 0.0,
  }) {
    if (pin == PinType.camera) {
      return true;
    }
    final distance = angularDistanceTo(cameraYaw, cameraPitch);
    return distance <= (fov / 2.0) + marginDegrees;
  }

  Offset? projectToViewport({
    required double cameraYaw,
    required double cameraPitch,
    double cameraRoll = 0.0,
    required double fov,
    required Size viewportSize,
  }) {
    final effectiveYaw = (pin == PinType.camera) ? 0.0 : cameraYaw;
    final effectivePitch = (pin == PinType.camera) ? 0.0 : cameraPitch;
    final effectiveRoll = (pin == PinType.camera) ? 0.0 : cameraRoll;

    final azRad = azimuthal * math.pi / 180.0;
    final elRad = polar * math.pi / 180.0;

    final xw = math.cos(elRad) * math.sin(azRad);
    final yw = math.sin(elRad);
    final zw = math.cos(elRad) * math.cos(azRad);

    final yawRad = effectiveYaw * math.pi / 180.0;
    final pitchRad = effectivePitch * math.pi / 180.0;
    final rollRad = effectiveRoll * math.pi / 180.0;

    final x1 = xw * math.cos(yawRad) - zw * math.sin(yawRad);
    final y1 = yw;
    final z1 = xw * math.sin(yawRad) + zw * math.cos(yawRad);

    final x2 = x1;
    final y2 = y1 * math.cos(pitchRad) - z1 * math.sin(pitchRad);
    final z2 = y1 * math.sin(pitchRad) + z1 * math.cos(pitchRad);

    final x3 = x2 * math.cos(rollRad) + y2 * math.sin(rollRad);
    final y3 = -x2 * math.sin(rollRad) + y2 * math.cos(rollRad);
    final z3 = z2;

    if (z3 <= 0.001) {
      return null;
    }

    final fovRad = fov * math.pi / 180.0;
    final f = (viewportSize.width / 2.0) / math.tan(fovRad / 2.0);

    final screenX = viewportSize.width / 2.0 + (x3 / z3) * f;
    final screenY = viewportSize.height / 2.0 - (y3 / z3) * f;

    return Offset(screenX, screenY);
  }

  SphericalCoordinate copyWith({
    double? polar,
    double? azimuthal,
    double? radius,
    PinType? pin,
  }) {
    return SphericalCoordinate(
      polar: polar ?? this.polar,
      azimuthal: azimuthal ?? this.azimuthal,
      radius: radius ?? this.radius,
      pin: pin ?? this.pin,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SphericalCoordinate &&
          runtimeType == other.runtimeType &&
          polar == other.polar &&
          azimuthal == other.azimuthal &&
          radius == other.radius &&
          pin == other.pin;

  @override
  int get hashCode =>
      polar.hashCode ^ azimuthal.hashCode ^ radius.hashCode ^ pin.hashCode;

  @override
  String toString() =>
      'SphericalCoordinate(polar: $polar, azimuthal: $azimuthal, radius: $radius, pin: $pin)';
}

class ViewportCamera {
  double yaw;
  double pitch;
  double roll;
  double fov;

  ViewportCamera({
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
    this.fov = 90.0,
  });

  void pan(double dx, double dy, {double sensitivity = 0.3}) {
    yaw = SphericalCoordinate.normalizeDegrees(yaw - dx * sensitivity);
    pitch = (pitch + dy * sensitivity).clamp(-85.0, 85.0);
  }

  void zoom(double deltaFov) {
    fov = (fov + deltaFov).clamp(30.0, 120.0);
  }

  void rotateKey({
    double deltaYaw = 0.0,
    double deltaPitch = 0.0,
    double deltaRoll = 0.0,
    double deltaFov = 0.0,
  }) {
    yaw = SphericalCoordinate.normalizeDegrees(yaw + deltaYaw);
    pitch = (pitch + deltaPitch).clamp(-85.0, 85.0);
    roll = roll + deltaRoll;
    fov = (fov + deltaFov).clamp(30.0, 120.0);
  }
}
