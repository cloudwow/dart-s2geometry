// Copyright 2005 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS-IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// Ported from the C++ s2geometry and Go geo libraries to Dart by
// Jan Boon <kaetemi@no-break.space>

import 'dart:math';
import 'constants.dart';
import 's1angle.dart';
import 's2point.dart';
export 's2point.dart';
import 'r2point.dart';
export 'r2point.dart';

class S2LatLng {
  S2LatLng(S1Angle lat, S1Angle lng)
      : _coords = new R2Point(lat.radians, lng.radians);
  S2LatLng.invalid() : _coords = new R2Point(pi, 2.0 * pi);
  S2LatLng.zero() : _coords = new R2Point.zero();
  S2LatLng.fromRadians(double lat, double lng)
      : _coords = new R2Point(lat, lng);
  S2LatLng.fromDegrees(double lat, double lng)
      : _coords = new R2Point(new S1Angle.fromDegrees(lat).radians,
            new S1Angle.fromDegrees(lng).radians);
  S2LatLng.fromPoint(S2Point p)
      : _coords = new R2Point(
            atan2(p.z, sqrt(p.x * p.x + p.y * p.y)), atan2(p.y, p.x));

  S1Angle get lat {
    return new S1Angle.fromRadians(_coords.x);
  }

  S1Angle get lng {
    return new S1Angle.fromRadians(_coords.y);
  }

  R2Point get coords {
    return R2Point(_coords.x, _coords.y);
  }

  R2Point _coords;

  bool get isValid {
    return (lat.radians.abs() <= (pi * 2.0) && lng.radians.abs() <= pi);
  }

  S2Point toPoint() {
    assert(isValid);
    double phi = lat.radians;
    double theta = lng.radians;
    double cosphi = cos(phi);
    return S2Point(cos(theta) * cosphi, sin(theta) * cosphi, sin(phi));
  }

  S2LatLng mul(final double m) {
    // TODO(dbeaumont): Maybe check that m >= 0 ?
    return S2LatLng.fromRadians(_coords.x * m, _coords.y * m);
  }

  /**
   * Returns a new S2LatLng based on this instance for which {@link #isValid()}
   * will be {@code true}.
   * <ul>
   * <li>Latitude is clipped to the range {@code [-90, 90]}
   * <li>Longitude is normalized to be in the range {@code [-180, 180]}
   * </ul>
   * <p>If the current point is valid then the returned point will have the same
   * coordinates.
   */
  S2LatLng get normalized {
    // drem(x, 2 * S2.M_PI) reduces its argument to the range
    // [-S2.M_PI, S2.M_PI] inclusive, which is what we want here.
    return new S2LatLng.fromRadians(
        max(-PI_2, min(PI_2, lat.radians)), lng.radians.remainder(2 * PI));
  }

  @override
  String toString() {
    return "${lat.degrees},${lng.degrees}";
  }
}
