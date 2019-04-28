import 'dart:math';

/**
 * An R1Interval represents a closed, bounded interval on the real line. It is
 * capable of representing the empty interval (containing no points) and
 * zero-length intervals (containing a single point).
 *
 */
class R1Interval {
  final double lo;
  final double hi;

  /** Interval constructor. If lo > hi, the interval is empty. */
  R1Interval({this.lo: 1.0, this.hi: 0.0});

  static R1Interval empty() {
    return new R1Interval(lo: 1, hi: 0);
  }

  /**
   * Convenience method to construct an interval containing a single point.
   */
  static R1Interval fromPoint(double p) {
    return R1Interval(lo: p, hi: p);
  }

  /**
   * Convenience method to construct the minimal interval containing the two
   * given points. This is equivalent to starting with an empty interval and
   * calling AddPoint() twice, but it is more efficient.
   */
  static R1Interval fromPointPair(double p1, double p2) {
    if (p1 <= p2) {
      return new R1Interval(lo: p1, hi: p2);
    } else {
      return new R1Interval(lo: p2, hi: p1);
    }
  }

  /**
   * Return true if the interval is empty, i.e. it contains no points.
   */
  bool get isEmpty => lo > hi;

  /**
   * Return the center of the interval. For empty intervals, the result is
   * arbitrary.
   */
  double get center => 0.5 * (lo + hi);

  /**
   * Return the length of the interval. The length of an empty interval is
   * negative.
   */
  double get length => hi - lo;

  bool contains1(double p) {
    return p >= lo && p <= hi;
  }

  bool interiorContains1(double p) {
    return p > lo && p < hi;
  }

  /** Return true if this interval contains the interval 'y'. */
  bool contains2(R1Interval y) {
    if (y.isEmpty) {
      return true;
    }
    return y.lo >= lo && y.hi <= hi;
  }

  /**
   * Return true if the interior of this interval contains the entire interval
   * 'y' (including its boundary).
   */
  bool interiorContains2(R1Interval y) {
    if (y.isEmpty) {
      return true;
    }
    return y.lo > lo && y.hi < hi;
  }

  /**
   * Return true if this interval intersects the given interval, i.e. if they
   * have any points in common.
   */
  bool intersects(R1Interval y) {
    if (lo <= y.lo) {
      return y.lo <= hi && y.lo <= y.hi;
    } else {
      return lo <= y.hi && lo <= hi;
    }
  }

  /**
   * Return true if the interior of this interval intersects any point of the
   * given interval (including its boundary).
   */
  bool interiorIntersects(R1Interval y) {
    return y.lo < hi && lo < y.hi && lo < hi && y.lo <= y.hi;
  }

  /** Expand the interval so that it contains the given point "p". */
  R1Interval addPoint(double p) {
    if (isEmpty) {
      return R1Interval.fromPoint(p);
    } else if (p < lo) {
      return new R1Interval(lo: p, hi: hi);
    } else if (p > hi) {
      return new R1Interval(lo: lo, hi: p);
    } else {
      return new R1Interval(lo: lo, hi: hi);
    }
  }

  /**
   * Return an interval that contains all points with a distance "radius" of a
   * point in this interval. Note that the expansion of an empty interval is
   * always empty.
   */
  R1Interval expanded(double radius) {
    // assert (radius >= 0);
    if (isEmpty) {
      return this;
    }
    return new R1Interval(lo: lo - radius, hi: hi + radius);
  }

  /**
   * Return the smallest interval that contains this interval and the given
   * interval "y".
   */
  R1Interval union(R1Interval y) {
    if (isEmpty) {
      return y;
    }
    if (y.isEmpty) {
      return this;
    }
    return new R1Interval(lo: min(lo, y.lo), hi: max(hi, y.hi));
  }

  /**
   * Return the intersection of this interval with the given interval. Empty
   * intervals do not need to be special-cased.
   */
  R1Interval intersection(R1Interval y) {
    return new R1Interval(lo: max(lo, y.lo), hi: min(hi, y.hi));
  }

  bool equals(Object that) {
    if (that is R1Interval) {
      R1Interval y = that;
      // Return true if two intervals contain the same set of points.
      return (lo == y.lo && hi == y.hi) || (isEmpty && y.isEmpty);
    }
    return false;
  }

  int get hashCode {
    if (isEmpty) {
      return 17;
    }

    return lo.hashCode + hi.hashCode;
  }

  bool approxEquals(R1Interval y) {
    return approxEquals2(y, 1e-15);
  }

  /**
   * Return true if length of the symmetric difference between the two intervals
   * is at most the given tolerance.
   *
   */
  bool approxEquals2(R1Interval y, double maxError) {
    if (isEmpty) {
      return y.length <= maxError;
    }
    if (y.isEmpty) {
      return length <= maxError;
    }
    return (y.lo - lo).abs() + (y.hi - hi).abs() <= maxError;
  }

  String toString() {
    return "[$lo, $hi]";
  }
}
