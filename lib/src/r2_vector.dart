/*
 * Copyright 2005 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * R2Vector represents a vector in the two-dimensional space. It defines the
 * basic geometrical operations for 2D vectors, e.g. cross product, addition,
 * norm, comparison etc.
 *
 */
class R2Vector {
   final double x;
   final double y;


  R2Vector({this. x:0, this. y:0}) ;

  static R2Vector fromCoords (List<double> coord) {
    assert (coord.length == 2);
    return R2Vector(x: coord[0],   y : coord[1]);
  }


  double get(int index) {
    assert(index <2);
    return index == 0 ? this.x : this.y;
  }

  static R2Vector add(final R2Vector p1, final R2Vector p2) {
    return new R2Vector(x:p1.x + p2.x,y: p1.y + p2.y);
  }

  static R2Vector mul(final R2Vector p, double m) {
    return new R2Vector(x:m * p.x,y: m * p.y);
  }

  double norm2() {
    return (x * x) + (y * y);
  }

  static double dotProd(final R2Vector p1, final R2Vector p2) {
    return (p1.x * p2.x) + (p1.y * p2.y);
  }

  double dotProdWith(R2Vector that) {
    return dotProd(this, that);
  }

  double crossProd(final R2Vector that) {
    return this.x * that.y - this.y * that.x;
  }

  bool lessThan(R2Vector vb) {
    if (x < vb.x) {
      return true;
    }
    if (vb.x < x) {
      return false;
    }
    if (y < vb.y) {
      return true;
    }
    return false;
  }

  
  bool equals(R2Vector thatPoint) {
    
    return this.x == thatPoint.x && this.y == thatPoint.y;
  }

  /**
   * Calcualates hashcode based on stored coordinates. Since we want +0.0 and
   * -0.0 to be treated the same, we ignore the sign of the coordinates.
   */
  
  int get hashCode {
    double value = 17;
    value += 37 * value + x;
    value += 37 * value + y;
    int valueInt = value.toInt();
    return (valueInt ^ (valueInt >> 32));
  }

  
  String toString() {
    return "R1Vector[x:$x, y:$y]";
  }
}