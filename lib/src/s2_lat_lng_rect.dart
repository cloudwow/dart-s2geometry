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
 * An S2LatLngRect represents a latitude-longitude rectangle. It is capable of
 * representing the empty and full rectangles as well as single points.
 *
 */
import 'dart:math';
import "r1_interval.dart";
import "s1_interval.dart";
import 's2latlng.dart';
import 'constants.dart';
import 's1angle.dart';
import 's2.dart';
import 's2_edge_util.dart';

class S2LatLngRect {
  final R1Interval lat;
  final S1Interval lng;

  S2LatLngRect({this.lat, this.lng});
  /**
   * Construct a rectangle from minimum and maximum latitudes and longitudes. If
   * lo.lng > hi.lng, the rectangle spans the 180 degree longitude line.
   */
  static S2LatLngRect ofLatLng(S2LatLng lo, S2LatLng hi) {
    var lat = R1Interval(lo: lo.lat.radians, hi: hi.lat.radians);
    var lng = S1Interval(lo: lo.lng.radians, hi: hi.lng.radians);
    return S2LatLngRect(lat: lat, lng: lng);
  }

  /** The canonical empty rectangle */
  static S2LatLngRect empty() {
    return S2LatLngRect(lat: R1Interval.empty(), lng: S1Interval.empty());
  }

  /** The canonical full rectangle. */
  static S2LatLngRect full() {
    return new S2LatLngRect(lat: fullLat(), lng: fullLng());
  }

  /** The full allowable range of latitudes. */
  static R1Interval fullLat() {
    return new R1Interval(lo: -PI_2, hi: PI_2);
  }

  /**
   * The full allowable range of longitudes.
   */
  static S1Interval fullLng() {
    return S1Interval.full();
  }

  /**
   * Construct a rectangle from a center point (in lat-lng space) and size in
   * each dimension. If size.lng is greater than 360 degrees it is clamped,
   * and latitudes greater than +/- 90 degrees are also clamped. So for example,
   * FromCenterSize((80,170),(20,20)) -> (lo=(60,150),hi=(90,-170)).
   */
  static S2LatLngRect fromCenterSize(S2LatLng center, S2LatLng size) {
    return fromPoint(center).expanded(size.mul(0.5));
  }

  /** Convenience method to construct a rectangle containing a single point. */
  static S2LatLngRect fromPoint(S2LatLng p) {
    // assert (p.isValid());
    return S2LatLngRect.ofLatLng(p, p);
  }

  /**
   * Convenience method to construct the minimal bounding rectangle containing
   * the two given points. This is equivalent to starting with an empty
   * rectangle and calling AddPoint() twice. Note that it is different than the
   * S2LatLngRect(lo, hi) constructor, where the first point is always used as
   * the lower-left corner of the resulting rectangle.
   */
  static S2LatLngRect fromPointPair(S2LatLng p1, S2LatLng p2) {
    // assert (p1.isValid() && p2.isValid());
    return S2LatLngRect(
        lat: R1Interval.fromPointPair(p1.lat.radians, p2.lat.radians),
        lng: S1Interval.fromPointPair(p1.lng.radians, p2.lng.radians));
  }

  /**
   * Return a latitude-longitude rectangle that contains the edge from "a" to
   * "b". Both points must be unit-length. Note that the bounding rectangle of
   * an edge can be larger than the bounding rectangle of its endpoints.
   */
  static S2LatLngRect fromEdge(S2Point a, S2Point b) {
    // assert (S2.isUnitLength(a) && S2.isUnitLength(b));
    S2LatLngRect r =
        fromPointPair(S2LatLng.fromPoint(a), S2LatLng.fromPoint(b));

    // Check whether the min/max latitude occurs in the edge interior.
    // We find the normal to the plane containing AB, and then a vector "dir" in
    // this plane that also passes through the equator. We use RobustCrossProd
    // to ensure that the edge normal is accurate even when the two points are
    // very close together.
    S2Point ab = S2.robustCrossProd(a, b);
    S2Point dir = S2Point.crossProd(ab, new S2Point(0, 0, 1));
    double da = dir.dotProd(a);
    double db = dir.dotProd(b);
    if (da * db >= 0) {
      // Minimum and maximum latitude are attained at the vertices.
      return r;
    }
    // Minimum/maximum latitude occurs in the edge interior. This affects the
    // latitude bounds but not the longitude bounds.
    double absLat = acos(ab.z / ab.norm.abs());
    if (da < 0) {
      return new S2LatLngRect(
          lat: new R1Interval(lo: r.lat.lo, hi: absLat), lng: r.lng);
    } else {
      return new S2LatLngRect(
          lat: new R1Interval(lo: -absLat, hi: r.lat.hi), lng: r.lng);
    }
  }

  /**
   * Return true if the rectangle is valid, which essentially just means that
   * the latitude bounds do not exceed Pi/2 in absolute value and the longitude
   * bounds do not exceed Pi in absolute value.
   *
   */
  bool isValid() {
    // The lat/lng ranges must either be both empty or both non-empty.
    return lat.lo.abs() <= PI_2 &&
        lat.hi.abs() <= PI_2 &&
        lng.isValid() &&
        lat.isEmpty == lng.isEmpty;
  }

  // Accessor methods.
  S1Angle latLo() {
    return S1Angle.fromRadians(lat.lo);
  }

  S1Angle latHi() {
    return S1Angle.fromRadians(lat.hi);
  }

  S1Angle lngLo() {
    return S1Angle.fromRadians(lng.lo);
  }

  S1Angle lngHi() {
    return S1Angle.fromRadians(lng.hi);
  }

  S2LatLng lo() {
    return new S2LatLng(latLo(), lngLo());
  }

  S2LatLng hi() {
    return new S2LatLng(latHi(), lngHi());
  }

  /**
   * Return true if the rectangle is empty, i.e. it contains no points at all.
   */
  bool get isEmpty {
    return lat.isEmpty;
  }

  // Return true if the rectangle is full, i.e. it contains all points.
  bool get isFull {
    return lat.equals(fullLat()) && lng.isFull();
  }

  /**
   * Return true if lng_.lo > lng_.hi, i.e. the rectangle crosses the 180
   * degree latitude line.
   */
  bool get isInverted {
    return lng.isInverted();
  }

  /** Return the k-th vertex of the rectangle (k = 0,1,2,3) in CCW order. */
  S2LatLng getVertex(int k) {
    // Return the points in CCW order (SW, SE, NE, NW).
    switch (k) {
      case 0:
        return S2LatLng.fromRadians(lat.lo, lng.lo);
      case 1:
        return S2LatLng.fromRadians(lat.lo, lng.hi);
      case 2:
        return S2LatLng.fromRadians(lat.hi, lng.hi);
      case 3:
        return S2LatLng.fromRadians(lat.hi, lng.lo);
      default:
        throw new Exception("Invalid vertex index.");
    }
  }

  /**
   * Return the center of the rectangle in latitude-longitude space (in general
   * this is not the center of the region on the sphere).
   */
  S2LatLng getCenter() {
    return S2LatLng.fromRadians(lat.center, lng.getCenter());
  }

  /**
   * Return the minimum distance (measured along the surface of the sphere)
   * from a given point to the rectangle (both its boundary and its interior).
   * The latLng must be valid.
   */
  S1Angle getDistance(S2LatLng p) {
    // The algorithm here is the same as in getDistance(S2LagLngRect), only
    // with simplified calculations.
    S2LatLngRect a = this;

    assert(!a.isEmpty);
    assert(p.isValid);

    if (a.lng.contains(p.lng.radians)) {
      return S1Angle.fromRadians(
          max(0.0, max(p.lat.radians - a.lat.hi, a.lat.lo - p.lat.radians)));
    }

    S1Interval interval =
        new S1Interval(lo: a.lng.hi, hi: a.lng.complement().getCenter());
    double aLng = a.lng.lo;
    if (interval.contains(p.lng.radians)) {
      aLng = a.lng.hi;
    }

    S2Point lo = S2LatLng.fromRadians(a.lat.lo, aLng).toPoint();
    S2Point hi = S2LatLng.fromRadians(a.lat.hi, aLng).toPoint();
    S2Point loCrossHi =
        S2LatLng.fromRadians(0, aLng - PI_2).normalized.toPoint();
    return S2EdgeUtil.getDistanceWithCross(p.toPoint(), lo, hi, loCrossHi);
  }

  /**
   * Return the minimum distance (measured along the surface of the sphere) to
   * the given S2LatLngRect. Both S2LatLngRects must be non-empty.
   */
  S1Angle getDistanceToRect(S2LatLngRect other) {
    S2LatLngRect a = this;
    S2LatLngRect b = other;

    assert(!a.isEmpty);
    assert(!b.isEmpty);

    // First, handle the trivial cases where the longitude intervals overlap.
    if (a.lng.intersects(b.lng)) {
      if (a.lat.intersects(b.lat)) {
        return S1Angle.fromRadians(0); // Intersection between a and b.
      }

      // We found an overlap in the longitude interval, but not in the latitude
      // interval. This means the shortest path travels along some line of
      // longitude connecting the high-latitude of the lower rect with the
      // low-latitude of the higher rect.
      S1Angle lo, hi;
      if (a.lat.lo > b.lat.hi) {
        lo = b.latHi();
        hi = a.latLo();
      } else {
        lo = a.latHi();
        hi = b.latLo();
      }
      return S1Angle.fromRadians(hi.radians - lo.radians);
    }

    // The longitude intervals don't overlap. In this case, the closest points
    // occur somewhere on the pair of longitudinal edges which are nearest in
    // longitude-space.
    S1Angle aLng, bLng;
    S1Interval loHi = S1Interval.fromPointPair(a.lng.lo, b.lng.hi);
    S1Interval hiLo = S1Interval.fromPointPair(a.lng.hi, b.lng.lo);
    if (loHi.getLength() < hiLo.getLength()) {
      aLng = a.lngLo();
      bLng = b.lngHi();
    } else {
      aLng = a.lngHi();
      bLng = b.lngLo();
    }

    // The shortest distance between the two longitudinal segments will include
    // at least one segment endpoint. We could probably narrow this down further
    // to a single point-edge distance by comparing the relative latitudes of the
    // endpoints, but for the sake of clarity, we'll do all four point-edge
    // distance tests.
    S2Point aLo = new S2LatLng(a.latLo(), aLng).toPoint();
    S2Point aHi = new S2LatLng(a.latHi(), aLng).toPoint();
    S2Point aLoCrossHi =
        S2LatLng.fromRadians(0, aLng.radians - PI_2).normalized.toPoint();
    S2Point bLo = new S2LatLng(b.latLo(), bLng).toPoint();
    S2Point bHi = new S2LatLng(b.latHi(), bLng).toPoint();
    S2Point bLoCrossHi =
        S2LatLng.fromRadians(0, bLng.radians - PI_2).normalized.toPoint();

    return S1Angle.min(
        S2EdgeUtil.getDistanceWithCross(aLo, bLo, bHi, bLoCrossHi),
        S1Angle.min(
            S2EdgeUtil.getDistanceWithCross(aHi, bLo, bHi, bLoCrossHi),
            S1Angle.min(
                S2EdgeUtil.getDistanceWithCross(bLo, aLo, aHi, aLoCrossHi),
                S2EdgeUtil.getDistanceWithCross(bHi, aLo, aHi, aLoCrossHi))));
  }

  /**
   * Return the width and height of this rectangle in latitude-longitude space.
   * Empty rectangles have a negative width and height.
   */
  S2LatLng getSize() {
    return S2LatLng.fromRadians(lat.length, lng.getLength());
  }

  /**
   * More efficient version of Contains() that accepts a S2LatLng rather than an
   * S2Point.
   */
  bool contains(S2LatLng ll) {
    // assert (ll.isValid());
    return (lat.contains1(ll.lat.radians) && lng.contains(ll.lng.radians));
  }

  /**
   * Return true if and only if the given point is contained in the interior of
   * the region (i.e. the region excluding its boundary). The point 'p' does not
   * need to be normalized.
   */
  bool interiorContains(S2Point p) {
    return interiorContainsLatLng(S2LatLng.fromPoint(p));
  }

  /**
   * More efficient version of InteriorContains() that accepts a S2LatLng rather
   * than an S2Point.
   */
  bool interiorContainsLatLng(S2LatLng ll) {
    // assert (ll.isValid());
    return (lat.interiorContains1(ll.lat.radians) &&
        lng.interiorContains(ll.lng.radians));
  }

  /**
   * Return true if and only if the rectangle contains the given other
   * rectangle.
   */
  bool containsRect(S2LatLngRect other) {
    return lat.contains2(other.lat) && lng.contains1(other.lng);
  }

  /**
   * Return true if and only if the interior of this rectangle contains all
   * points of the given other rectangle (including its boundary).
   */
  bool interiorContainsRect(S2LatLngRect other) {
    return (lat.interiorContains2(other.lat) &&
        lng.interiorContains1(other.lng));
  }

  /** Return true if this rectangle and the given other rectangle have any
  points in common. */
  bool intersects(S2LatLngRect other) {
    return lat.intersects(other.lat) && lng.intersects(other.lng);
  }

  /**
   * Return true if and only if the interior of this rectangle intersects any
   * point (including the boundary) of the given other rectangle.
   */
  bool interiorIntersects(S2LatLngRect other) {
    return (lat.interiorIntersects(other.lat) &&
        lng.interiorIntersects(other.lng));
  }

  S2LatLngRect addPoint(S2Point p) {
    return addLatLng(S2LatLng.fromPoint(p));
  }

  // Increase the size of the bounding rectangle to include the given point.
  // The rectangle is expanded by the minimum amount possible.
  S2LatLngRect addLatLng(S2LatLng ll) {
    // assert (ll.isValid());
    R1Interval newLat = lat.addPoint(ll.lat.radians);
    S1Interval newLng = lng.addPoint(ll.lng.radians);
    return new S2LatLngRect(lat: newLat, lng: newLng);
  }

  /**
   * Return a rectangle that contains all points whose latitude distance from
   * this rectangle is at most margin.lat, and whose longitude distance from
   * this rectangle is at most margin.lng. In particular, latitudes are
   * clamped while longitudes are wrapped. Note that any expansion of an empty
   * interval remains empty, and both components of the given margin must be
   * non-negative.
   *
   * NOTE: If you are trying to grow a rectangle by a certain *distance* on the
   * sphere (e.g. 5km), use the ConvolveWithCap() method instead.
   */
  S2LatLngRect expanded(S2LatLng margin) {
    // assert (margin.lat.radians >= 0 && margin.lng.radians >= 0);
    if (isEmpty) {
      return this;
    }
    return new S2LatLngRect(
        lat: lat.expanded(margin.lat.radians).intersection(fullLat()),
        lng: lng.expanded(margin.lng.radians));
  }

  /**
   * Return the smallest rectangle containing the union of this rectangle and
   * the given rectangle.
   */
  S2LatLngRect union(S2LatLngRect other) {
    return new S2LatLngRect(
        lat: lat.union(other.lat), lng: lng.union(other.lng));
  }

  /**
   * Return the smallest rectangle containing the intersection of this rectangle
   * and the given rectangle. Note that the region of intersection may consist
   * of two disjoint rectangles, in which case a single rectangle spanning both
   * of them is returned.
   */
  S2LatLngRect intersection(S2LatLngRect other) {
    R1Interval intersectLat = lat.intersection(other.lat);
    S1Interval intersectLng = lng.intersection(other.lng);
    if (intersectLat.isEmpty || intersectLng.isEmpty()) {
      // The lat/lng ranges must either be both empty or both non-empty.
      return empty();
    }
    return new S2LatLngRect(lat: intersectLat, lng: intersectLng);
  }

  /** Return the surface area of this rectangle on the unit sphere. */
  double get area {
    if (isEmpty) {
      return 0;
    }

    // This is the size difference of the two spherical caps, multiplied by
    // the longitude ratio.
    return lng.getLength() *
        (sin(latHi().radians) - sin(latLo().radians)).abs();
  }

  /** Return true if two rectangles contains the same set of points. */
  bool equals(S2LatLngRect that) {
    return lat.equals(that.lat) && lng.equals(that.lng);
  }

  /**
   * Return true if the latitude and longitude intervals of the two rectangles
   * are the same up to the given tolerance (see r1interval.h and s1interval.h
   * for details).
   */
  bool approxEquals(S2LatLngRect other) {
    return (lat.approxEquals(other.lat) && lng.approxEquals(other.lng, 1e-15));
  }

  int get hashCode {
    int v = 17;
    v = 37 * v + lat.hashCode;
    return (37 * v + lng.hashCode);
  }

  S2LatLngRect getRectBound() {
    return this;
  }

  /** The point 'p' does not need to be normalized. */
  bool containsPoint(S2Point p) {
    return contains(S2LatLng.fromPoint(p));
  }

  /**
   * Return true if the edge AB intersects the given edge of constant longitude.
   */
  static bool intersectsLngEdge(
      S2Point a, S2Point b, R1Interval lat, double lng) {
    // Return true if the segment AB intersects the given edge of constant
    // longitude. The nice thing about edges of constant longitude is that
    // they are straight lines on the sphere (geodesics).

    return S2.simpleCrossing(a, b, S2LatLng.fromRadians(lat.lo, lng).toPoint(),
        S2LatLng.fromRadians(lat.hi, lng).toPoint());
  }

  /**
   * Return true if the edge AB intersects the given edge of constant latitude.
   */
  static bool intersectsLatEdge(
      S2Point a, S2Point b, double lat, S1Interval lng) {
    // Return true if the segment AB intersects the given edge of constant
    // latitude. Unfortunately, lines of constant latitude are curves on
    // the sphere. They can intersect a straight edge in 0, 1, or 2 points.
    // assert (S2.isUnitLength(a) && S2.isUnitLength(b));

    // First, compute the normal to the plane AB that points vaguely north.
    S2Point z = S2Point.normalize(S2.robustCrossProd(a, b));
    if (z.z < 0) {
      z = S2Point.negative(z);
    }

    // Extend this to an orthonormal frame (x,y,z) where x is the direction
    // where the great circle through AB achieves its maximium latitude.
    S2Point y = S2Point.normalize(S2.robustCrossProd(z, new S2Point(0, 0, 1)));
    S2Point x = S2Point.crossProd(y, z);
    // assert (S2.isUnitLength(x) && x.z >= 0);

    // Compute the angle "theta" from the x-axis (in the x-y plane defined
    // above) where the great circle intersects the given line of latitude.
    double sinLat = sin(lat);
    if (sinLat.abs() >= x.z) {
      return false; // The great circle does not reach the given latitude.
    }
    // assert (x.z > 0);
    double cosTheta = sinLat / x.z;
    double sinTheta = sqrt(1 - cosTheta * cosTheta);
    double theta = atan2(sinTheta, cosTheta);

    // The candidate intersection points are located +/- theta in the x-y
    // plane. For an intersection to be valid, we need to check that the
    // intersection point is contained in the interior of the edge AB and
    // also that it is contained within the given longitude interval "lng".

    // Compute the range of theta values spanned by the edge AB.
    S1Interval abTheta = S1Interval.fromPointPair(
        atan2(a.dotProd(y), a.dotProd(x)), atan2(b.dotProd(y), b.dotProd(x)));

    if (abTheta.contains(theta)) {
      // Check if the intersection point is also in the given "lng" interval.
      S2Point isect =
          S2Point.add(S2Point.mul(x, cosTheta), S2Point.mul(y, sinTheta));
      if (lng.contains(atan2(isect.y, isect.x))) {
        return true;
      }
    }
    if (abTheta.contains(-theta)) {
      // Check if the intersection point is also in the given "lng" interval.
      S2Point intersection =
          S2Point.sub(S2Point.mul(x, cosTheta), S2Point.mul(y, sinTheta));
      if (lng.contains(atan2(intersection.y, intersection.x))) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() {
    return "S2Rect[Lo=${lo()}, Hi=${hi()}]";
  }
}
