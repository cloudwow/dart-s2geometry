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
 * An S2Cell is an S2Region object that represents a cell. Unlike S2CellIds, it
 * supports efficient containment and intersection tests. However, it is also a
 * more expensive representation.
 *
 */
import 's1angle.dart';
import 's2cell_id.dart';
import 'dart:math';
import 'constants.dart';
import 's2latlng.dart';
import 's2.dart';
import 'mutableinteger.dart';
import 'r1_interval.dart';
import 's1_interval.dart';
import 's2_lat_lng_rect.dart';
import 's2_projections.dart';

class S2Cell {
  final int MAX_CELL_SIZE = 1 << MAX_LEVEL;

  int face;
  int level;
  int orientation;
  S2CellId cellId;
  List<List<double>> uv;

  // Convenience methods.
  S2Cell({S2CellId id, S2Point point, S2LatLng latLng}) {
    if (id != null) {
      init(id);
    } else if (point != null) {
      init(S2CellId.fromPoint(point));
    } else if (latLng != null) {
      init(S2CellId.fromLatLng(latLng));
    } else {
      assert(false);
    }
  }

  S2CellId get id => cellId;

  bool get isLeaf => level == MAX_LEVEL;

  S2Point getVertex(int k) {
    return S2Point.normalize(getVertexRaw(k));
  }

  /**
   * Return the k-th vertex of the cell (k = 0,1,2,3). Vertices are returned in
   * CCW order. The points returned by GetVertexRaw are not necessarily unit
   * length.
   */
  S2Point getVertexRaw(int k) {
    // Vertices are returned in the order SW, SE, NE, NW.
    return S2Projections.faceUvToXyz(
        face, uv[0][(k >> 1) ^ (k & 1)], uv[1][k >> 1]);
  }

  S2Point getEdge(int k) {
    return S2Point.normalize(getEdgeRaw(k));
  }

  S2Point getEdgeRaw(int k) {
    switch (k) {
      case 0:
        return S2Projections.getVNorm(face, uv[1][0]); // South
      case 1:
        return S2Projections.getUNorm(face, uv[0][1]); // East
      case 2:
        return S2Point.negative(
            S2Projections.getVNorm(face, uv[1][1])); // North
      default:
        return S2Point.negative(S2Projections.getUNorm(face, uv[0][0])); // West
    }
  }

  /**
   * Return the direction vector corresponding to the center in (s,t)-space of
   * the given cell. This is the point at which the cell is divided into four
   * subcells; it is not necessarily the centroid of the cell in (u,v)-space or
   * (x,y,z)-space. The point returned by GetCenterRaw is not necessarily unit
   * length.
   */
  S2Point getCenter() {
    return S2Point.normalize(getCenterRaw());
  }

  S2Point getCenterRaw() {
    return cellId.toPointRaw();
  }

  S2LatLngRect getRectBound() {
    if (level > 0) {
      // Except for cells at level 0, the latitude and longitude extremes are
      // attained at the vertices. Furthermore, the latitude range is
      // determined by one pair of diagonally opposite vertices and the
      // longitude range is determined by the other pair.
      //
      // We first determine which corner (i,j) of the cell has the largest
      // absolute latitude. To maximize latitude, we want to find the point in
      // the cell that has the largest absolute z-coordinate and the smallest
      // absolute x- and y-coordinates. To do this we look at each coordinate
      // (u and v), and determine whether we want to minimize or maximize that
      // coordinate based on the axis direction and the cell's (u,v) quadrant.
      double u = uv[0][0] + uv[0][1];
      double v = uv[1][0] + uv[1][1];
      int i = S2Projections.getUAxis(face).z == 0
          ? (u < 0 ? 1 : 0)
          : (u > 0 ? 1 : 0);
      int j = S2Projections.getVAxis(face).z == 0
          ? (v < 0 ? 1 : 0)
          : (v > 0 ? 1 : 0);
      R1Interval lat = R1Interval.fromPointPair(
          getLatitude(i, j), getLatitude(1 - i, 1 - j));
      var fullLatRect = S2LatLngRect.fullLat();
      lat = lat.expanded(MAX_ERROR).intersection(fullLatRect);

      if (lat.lo == -PI_2 || lat.hi == PI_2) {
        return new S2LatLngRect(lat: lat, lng: S1Interval.full());
      }
      S1Interval lng = S1Interval.fromPointPair(
          getLongitude(i, 1 - j), getLongitude(1 - i, j));
      return new S2LatLngRect(lat: lat, lng: lng.expanded(MAX_ERROR));
    }

    // The face centers are the +X, +Y, +Z, -X, -Y, -Z axes in that order.
    // assert (S2Projections.getNorm(face).get(face % 3) == ((face < 3) ? 1 : -1));
    switch (face) {
      case 0:
        return new S2LatLngRect(
            lat: new R1Interval(lo: -PI_4, hi: PI_4),
            lng: new S1Interval(lo: -PI_4, hi: PI_4));
      case 1:
        return new S2LatLngRect(
            lat: new R1Interval(lo: -PI_4, hi: PI_4),
            lng: new S1Interval(lo: PI_4, hi: 3 * PI_4));
      case 2:
        return new S2LatLngRect(
            lat: new R1Interval(lo: POLE_MIN_LAT, hi: PI_2),
            lng: new S1Interval(lo: -PI, hi: PI));
      case 3:
        return new S2LatLngRect(
            lat: new R1Interval(lo: -PI_4, hi: PI_4),
            lng: new S1Interval(lo: 3 * PI_4, hi: -3 * PI_4));
      case 4:
        return new S2LatLngRect(
            lat: new R1Interval(lo: -PI_4, hi: PI_4),
            lng: new S1Interval(lo: -3 * PI_4, hi: -PI_4));
      default:
        return new S2LatLngRect(
            lat: new R1Interval(lo: -PI_2, hi: -POLE_MIN_LAT),
            lng: new S1Interval(lo: -PI, hi: PI));
    }
  }

  void init(S2CellId id) {
    cellId = id;
    int MAX_CELL_SIZE = 1 << MAX_LEVEL;
    List<MutableInteger> ij = [MutableInteger(0), MutableInteger(0)];
    MutableInteger mOrientation = MutableInteger(0);

    face = id.toFaceIJOrientation(ij[0], ij[1], mOrientation);
  //  print("i: ${ij[0].value}   j: ${ij[1].value}");
    orientation = mOrientation.value; // Compress int to a int.
    uv = List<List<double>>();

    level = id.level;
 //   print("level: $level");
    int cellSize = 1 << (MAX_LEVEL - level);
 //   print("cellSize: $cellSize");
    for (int d = 0; d < 2; ++d) {
      // Compute the cell bounds in scaled (i,j) coordinates.

      int sijLo = ij[d].value - (cellSize / 2).floor(); // * 2 - MAX_CELL_SIZE;
      int sijHi = sijLo + cellSize;
  //    print("d: $d");
 //     print("   sijLo: $sijLo   sijHi: $sijHi   d: $d");
      uv.add(List<double>());
  //    print("   UV LO ${S2Projections.stToUV((1.0 / MAX_CELL_SIZE) * sijLo)}");
      uv[d].add(S2Projections.stToUV((1.0 / MAX_CELL_SIZE) * sijLo));
  //    print("   UV HI ${S2Projections.stToUV((1.0 / MAX_CELL_SIZE) * sijHi)}");
      uv[d].add(S2Projections.stToUV((1.0 / MAX_CELL_SIZE) * sijHi));
    }
   // for (S2LatLng latlng in getMyRect()) {
   //   print(latlng);
   // }
  }

  List<S2LatLng> getMyRect() {
    return <S2LatLng>[
      derp(0, 0),
      derp(1, 0),
      derp(1, 1),
      derp(0, 1),
    ];
  }
  S2LatLng derp(int i, int j) {
        S2Point p = S2Projections.faceUvToXyz(face, uv[0][i], uv[1][j]);
       var latitude =atan2(p.z, sqrt(p.x * p.x + p.y * p.y));
       var longitude =atan2(p.y, p.x);       
    return S2LatLng.fromRadians(latitude, longitude);
  }

  // Internal method that does the actual work in the constructors.

  double getLatitude(int i, int j) {
    S2Point p = S2Projections.faceUvToXyz(face, uv[0][i], uv[1][j]);
    return atan2(p.z, sqrt(p.x * p.x + p.y * p.y));
  }

  double getLongitude(int i, int j) {
    S2Point p = S2Projections.faceUvToXyz(face, uv[0][i], uv[1][j]);
    return atan2(p.y, p.x);
  }

  // Return the latitude or longitude of the cell vertex given by (i,j),
  // where "i" and "j" are either 0 or 1.

  String toString() {
    return "face:$face, level:$level, orientation:$orientation cellId:$cellId, uv:$uv";
  }
}
