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
import "dart:math";

class S2Point {
  S2Point(this.x, this.y, this.z);
  double x, y, z;
  double operator [](int index) {
    switch (index) {
      case 0:
        return x;
      case 1:
        return y;
      case 2:
        return z;
      default:
        throw new Exception("Invalid index");
    }
  }

  bool equals(S2Point that) {
    return this.x == that.x && this.y == that.y && this.z == that.z;
  }

  double get magnitude {
    return sqrt(x * x + y * y + z * z);
  }

  S2Point normalized() {
    double m = magnitude;
    return S2Point(x / m, y / m, z / m);
  }

  S2Point abs() {
    return new S2Point(x.abs(), y.abs(), z.abs());
  }


  static S2Point negative(S2Point p) {
    return new S2Point(-p.x, -p.y, -p.z);
  }
  int largestAbsComponent() {
    S2Point temp = abs();
    return temp[0] > temp[1]
        ? temp[0] > temp[2] ? 0 : 2
        : temp[1] > temp[2] ? 1 : 2;
  }

  double get norm2 {
    return x * x + y * y + z * z;
  }

  double get norm {
    return sqrt(norm2);
  }

  static S2Point crossProd(final S2Point p1, final S2Point p2) {
    return new S2Point(p1.y * p2.z - p1.z * p2.y, p1.z * p2.x - p1.x * p2.z,
        p1.x * p2.y - p1.y * p2.x);
  }

  static S2Point add(final S2Point p1, final S2Point p2) {
    return new S2Point(p1.x + p2.x, p1.y + p2.y, p1.z + p2.z);
  }

  static S2Point sub(final S2Point p1, final S2Point p2) {
    return new S2Point(p1.x - p2.x, p1.y - p2.y, p1.z - p2.z);
  }

  double dotProd(S2Point that) {
    return this.x * that.x + this.y * that.y + this.z * that.z;
  }

  bool get isUnitLength {
    return norm2.abs() - 1 <= 1e-15;
  }

  static S2Point mul(final S2Point p, double m) {
    return new S2Point(m * p.x, m * p.y, m * p.z);
  }

  static S2Point div(final S2Point p, double m) {
    return new S2Point(p.x / m, p.y / m, p.z / m);
  }

  /** return a vector orthogonal to this one */
  S2Point ortho() {
    int k = largestAbsComponent();
    S2Point temp;
    if (k == 1) {
      temp = new S2Point(1, 0, 0);
    } else if (k == 2) {
      temp = new S2Point(0, 1, 0);
    } else {
      temp = new S2Point(0, 0, 1);
    }
    return S2Point.normalize(crossProd(this, temp));
  }

  static S2Point normalize(S2Point p) {
    double norm = p.norm;
    if (norm != 0) {
      norm = 1.0 / norm;
    }
    return S2Point.mul(p, norm);
  }

  static S2Point minus(S2Point p1, S2Point p2) {
    return sub(p1, p2);
  }

  @override
  String toString() {
    return "$x,$y,$z";
  }
}
