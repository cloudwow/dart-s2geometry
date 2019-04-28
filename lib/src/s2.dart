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
}
