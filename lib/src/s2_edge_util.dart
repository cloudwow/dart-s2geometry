import 'dart:math'; 
import 's2.dart';
import 's2point.dart';
import 's1angle.dart';
class S2EdgeUtil {

  /**
   * Return the minimum distance from X to any point on the edge AB. The result
   * is very accurate for small distances but may have some numerical error if
   * the distance is large (approximately Pi/2 or greater). The case A == B is
   * handled correctly. Note: x, a and b must be of unit length. Throws
   * IllegalArgumentException if this is not the case.
   */
   static S1Angle getDistance(S2Point x, S2Point a, S2Point b) {
    return getDistanceWithCross(x, a, b, S2.robustCrossProd(a, b));
  }

  /**
   * A slightly more efficient version of getDistance() where the cross product
   * of the two endpoints has been precomputed. The cross product does not need
   * to be normalized, but should be computed using S2.robustCrossProd() for the
   * most accurate results.
   */
   static S1Angle getDistanceWithCross(S2Point x, S2Point a, S2Point b, S2Point aCrossB) {
    assert(x.isUnitLength);
    assert(a.isUnitLength);
    assert(b.isUnitLength);

    // There are three cases. If X is located in the spherical wedge defined by
    // A, B, and the axis A x B, then the closest point is on the segment AB.
    // Otherwise the closest point is either A or B; the dividing line between
    // these two cases is the great circle passing through (A x B) and the
    // midpoint of AB.

    if (S2.simpleCCW(aCrossB, a, x) && S2.simpleCCW(x, b, aCrossB)) {
      // The closest point to X lies on the segment AB. We compute the distance
      // to the corresponding great circle. The result is accurate for small
      // distances but not necessarily for large distances (approaching Pi/2).

      double sinDist = x.dotProd(aCrossB).abs() / aCrossB.norm;
      return S1Angle.fromRadians(asin(min(1.0, sinDist)));
    }

    // Otherwise, the closest point is either A or B. The cheapest method is
    // just to compute the minimum of the two linear (as opposed to spherical)
    // distances and convert the result to an angle. Again, this method is
    // accurate for small but not large distances (approaching Pi).

    double linearDist2 = min(S2Point.minus(x, a).norm2(), S2Point.minus(x, b).norm2());
    return S1Angle.fromRadians(2 * asin(min(1.0, 0.5 * sqrt(linearDist2))));
  }
}