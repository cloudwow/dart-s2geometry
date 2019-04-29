import 's2point.dart';

class S2 {
  static S2Point robustCrossProd(S2Point a, S2Point b) {
    // The direction of a.CrossProd(b) becomes unstable as (a + b) or (a - b)
    // approaches zero. This leads to situations where a.CrossProd(b) is not
    // very orthogonal to "a" and/or "b". We could fix this using Gram-Schmidt,
    // but we also want b.RobustCrossProd(a) == -b.RobustCrossProd(a).
    //
    // The easiest fix is to just compute the cross product of (b+a) and (b-a).
    // Given that "a" and "b" are unit-length, this has good orthogonality to
    // "a" and "b" even if they differ only in the lowest bit of one component.

    // assert (isUnitLength(a) && isUnitLength(b));
    S2Point x = S2Point.crossProd(S2Point.add(b, a), S2Point.sub(b, a));
    if (!x.equals(new S2Point(0, 0, 0))) {
      return x;
    }

    // The only result that makes sense mathematically is to return zero, but
    // we find it more convenient to return an arbitrary orthogonal vector.
    return ortho(a);
  }

  /**
   * Return a unit-length vector that is orthogonal to "a". Satisfies Ortho(-a)
   * = -Ortho(a) for all a.
   */
  static S2Point ortho(S2Point a) {
    // The current implementation in S2Point has the property we need,
    // i.e. Ortho(-a) = -Ortho(a) for all a.
    return a.ortho();
  }

   /**
   * Return true if the points A, B, C are strictly counterclockwise. Return
   * false if the points are clockwise or colinear (i.e. if they are all
   * contained on some great circle).
   *
   *  Due to numerical errors, situations may arise that are mathematically
   * impossible, e.g. ABC may be considered strictly CCW while BCA is not.
   * However, the implementation guarantees the following:
   *
   *  If SimpleCCW(a,b,c), then !SimpleCCW(c,b,a) for all a,b,c.
   *
   * In other words, ABC and CBA are guaranteed not to be both CCW
   */
   static bool simpleCCW(S2Point a, S2Point b, S2Point c) {
    // We compute the signed volume of the parallelepiped ABC. The usual
    // formula for this is (AxB).C, but we compute it here using (CxA).B
    // in order to ensure that ABC and CBA are not both CCW. This follows
    // from the following identities (which are true numerically, not just
    // mathematically):
    //
    // (1) x.CrossProd(y) == -(y.CrossProd(x))
    // (2) (-x).DotProd(y) == -(x.DotProd(y))

    return S2Point.crossProd(c, a).dotProd(b) > 0;
  }


  /**
   * Return true if edge AB crosses CD at a point that is interior to both
   * edges. Properties:
   *
   *  (1) SimpleCrossing(b,a,c,d) == SimpleCrossing(a,b,c,d) (2)
   * SimpleCrossing(c,d,a,b) == SimpleCrossing(a,b,c,d)
   */
   static bool simpleCrossing(S2Point a, S2Point b, S2Point c, S2Point d) {
    // We compute SimpleCCW() for triangles ACB, CBD, BDA, and DAC. All
    // of these triangles need to have the same orientation (CW or CCW)
    // for an intersection to exist. Note that this is slightly more
    // restrictive than the corresponding definition for planar edges,
    // since we need to exclude pairs of line segments that would
    // otherwise "intersect" by crossing two antipodal points.

    S2Point ab = S2Point.crossProd(a, b);
    S2Point cd = S2Point.crossProd(c, d);
    double acb = -ab.dotProd(c);
    double cbd = -cd.dotProd(b);
    double bda = ab.dotProd(d);
    double dac = cd.dotProd(a);

    return (acb * cbd > 0) && (cbd * bda > 0) && (bda * dac > 0);
  }
}
