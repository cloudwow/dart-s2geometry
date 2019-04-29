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
 * This class specifies the details of how the cube faces are projected onto the
 * unit sphere. This includes getting the face ordering and orientation correct
 * so that sequentially increasing cell ids follow a continuous space-filling
 * curve over the entire sphere, and defining the transformation from cell-space
 * to cube-space (see s2.h) in order to make the cells more uniform in size.
 *
 *
 *  We have implemented three different projections from cell-space (s,t) to
 * cube-space (u,v): linear, quadratic, and tangent. They have the following
 * tradeoffs:
 *
 *  Linear - This is the fastest transformation, but also produces the least
 * uniform cell sizes. Cell areas vary by a factor of about 5.2, with the
 * largest cells at the center of each face and the smallest cells in the
 * corners.
 *
 *  Tangent - Transforming the coordinates via atan() makes the cell sizes more
 * uniform. The areas vary by a maximum ratio of 1.4 as opposed to a maximum
 * ratio of 5.2. However, each call to atan() is about as expensive as all of
 * the other calculations combined when converting from points to cell ids, i.e.
 * it reduces performance by a factor of 3.
 *
 *  Quadratic - This is an approximation of the tangent projection that is much
 * faster and produces cells that are almost as uniform in size. It is about 3
 * times faster than the tangent projection for converting cell ids to points,
 * and 2 times faster for converting points to cell ids. Cell areas vary by a
 * maximum ratio of about 2.1.
 *
 *  Here is a table comparing the cell uniformity using each projection. "Area
 * ratio" is the maximum ratio over all subdivision levels of the largest cell
 * area to the smallest cell area at that level, "edge ratio" is the maximum
 * ratio of the longest edge of any cell to the shortest edge of any cell at the
 * same level, and "diag ratio" is the ratio of the longest diagonal of any cell
 * to the shortest diagonal of any cell at the same level. "ToPoint" and
 * "FromPoint" are the times in microseconds required to convert cell ids to and
 * from points (unit vectors) respectively.
 *
 *  Area Edge Diag ToPoint FromPoint Ratio Ratio Ratio (microseconds)
 * ------------------------------------------------------- Linear: 5.200 2.117
 * 2.959 0.103 0.123 Tangent: 1.414 1.414 1.704 0.290 0.306 Quadratic: 2.082
 * 1.802 1.932 0.116 0.161
 *
 *  The worst-case cell aspect ratios are about the same with all three
 * projections. The maximum ratio of the longest edge to the shortest edge
 * within the same cell is about 1.4 and the maximum ratio of the diagonals
 * within the same cell is about 1.7.
 *
 * This data was produced using s2cell_unittest and s2cellid_unittest.
 *
 */
import 's2cell_id.dart';
import 'dart:math';
import 'constants.dart';
import 's2latlng.dart';
import 's2coords.dart';
import 's2.dart';
import 'mutableinteger.dart';
import 'r1_interval.dart';
import 's1_interval.dart';
import 's2_lat_lng_rect.dart';

enum Projections {
    S2_LINEAR_PROJECTION, S2_TAN_PROJECTION, S2_QUADRATIC_PROJECTION
  }

class S2Projections {
  
  static final Projections S2_PROJECTION = Projections.S2_QUADRATIC_PROJECTION;

  // All of the values below were obtained by a combination of hand analysis and
  // matica. In general, S2_TAN_PROJECTION produces the most uniform
  // shapes and sizes of cells, S2_LINEAR_PROJECTION is considerably worse, and
  // S2_QUADRATIC_PROJECTION is somewhere in between (but generally closer to
  // the tangent projection than the linear one).


  // This is the maximum edge aspect ratio over all cells at any level, where
  // the edge aspect ratio of a cell is defined as the ratio of its longest
  // edge length to its shortest edge length.
  static final double MAX_EDGE_ASPECT =
      S2_PROJECTION == Projections.S2_LINEAR_PROJECTION ? SQRT2 : // 1.414
      S2_PROJECTION == Projections.S2_TAN_PROJECTION ? SQRT2 : // 1.414
      S2_PROJECTION == Projections.S2_QUADRATIC_PROJECTION ? 1.44261527445268292 : // 1.443
      0;

  // This is the maximum diagonal aspect ratio over all cells at any level,
  // where the diagonal aspect ratio of a cell is defined as the ratio of its
  // longest diagonal length to its shortest diagonal length.
  static final double MAX_DIAG_ASPECT = sqrt(3); // 1.732

  static double stToUV(double s) {
    switch (S2_PROJECTION) {
      case Projections.S2_LINEAR_PROJECTION:
        return s;
      case Projections.S2_TAN_PROJECTION:
        // Unfortunately, tan(M_PI_4) is slightly less than 1.0. This isn't due
        // to
        // a flaw in the implementation of tan(), it's because the derivative of
        // tan(x) at x=pi/4 is 2, and it happens that the two adjacent floating
        // point numbers on either side of the infinite-precision value of pi/4
        // have
        // tangents that are slightly below and slightly above 1.0 when rounded
        // to
        // the nearest double-precision result.
        s = tan(PI_4 * s);
        return s + (1.0 / (1 << 53)) * s;
      case Projections.S2_QUADRATIC_PROJECTION:
        if (s >= 0) {
          return (1 / 3.0) * ((1 + s) * (1 + s) - 1);
        } else {
          return (1 / 3.0) * (1 - (1 - s) * (1 - s));
        }
        break;
      default:
        throw new Exception("Invalid value for S2_PROJECTION");
    }
  }

  static double uvToST(double u) {
    switch (S2_PROJECTION) {
      case Projections.S2_LINEAR_PROJECTION:
        return u;
      case Projections.S2_TAN_PROJECTION:
        return (4 * PI) * atan(u);
      case Projections.S2_QUADRATIC_PROJECTION:
        if (u >= 0) {
          return sqrt(1 + 3 * u) - 1;
        } else {
          return 1 - sqrt(1 - 3 * u);
        }
        break;
      default:
        throw new Exception("Invalid value for S2_PROJECTION");
    }
  }


  /**
   * Convert (face, u, v) coordinates to a direction vector (not necessarily
   * unit length).
   */
  static S2Point faceUvToXyz(int face, double u, double v) {
    switch (face) {
      case 0:
        return new S2Point(1, u, v);
      case 1:
        return new S2Point(-u, 1, v);
      case 2:
        return new S2Point(-u, -v, 1);
      case 3:
        return new S2Point(-1, -v, -u);
      case 4:
        return new S2Point(v, -1, -u);
      default:
        return new S2Point(v, u, -1);
    }
  }

  static S2Point getUNorm(int face, double u) {
    switch (face) {
      case 0:
        return new S2Point(u, -1, 0);
      case 1:
        return new S2Point(1, u, 0);
      case 2:
        return new S2Point(1, 0, u);
      case 3:
        return new S2Point(-u, 0, 1);
      case 4:
        return new S2Point(0, -u, 1);
      default:
        return new S2Point(0, -1, -u);
    }
  }

  static S2Point getVNorm(int face, double v) {
    switch (face) {
      case 0:
        return new S2Point(-v, 0, 1);
      case 1:
        return new S2Point(0, -v, 1);
      case 2:
        return new S2Point(0, -1, -v);
      case 3:
        return new S2Point(v, -1, 0);
      case 4:
        return new S2Point(1, v, 0);
      default:
        return new S2Point(1, 0, v);
    }
  }

  static S2Point getNorm(int face) {
    return faceUvToXyz(face, 0, 0);
  }

  static S2Point getUAxis(int face) {
    switch (face) {
      case 0:
        return new S2Point(0, 1, 0);
      case 1:
        return new S2Point(-1, 0, 0);
      case 2:
        return new S2Point(-1, 0, 0);
      case 3:
        return new S2Point(0, 0, -1);
      case 4:
        return new S2Point(0, 0, -1);
      default:
        return new S2Point(0, 1, 0);
    }
  }

  static S2Point getVAxis(int face) {
    switch (face) {
      case 0:
        return new S2Point(0, 0, 1);
      case 1:
        return new S2Point(0, 0, 1);
      case 2:
        return new S2Point(0, -1, 0);
      case 3:
        return new S2Point(0, -1, 0);
      case 4:
        return new S2Point(1, 0, 0);
      default:
        return new S2Point(1, 0, 0);
    }
  }

  // Don't instantiate
  S2Projections() {
  }
}