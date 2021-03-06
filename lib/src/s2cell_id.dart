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

import 'dart:typed_data';
import 'dart:math';
import 'package:s2geometry/src/s2_projections.dart';
import 's2coords_impl.dart';
import 's2coords.dart';
import 'constants.dart';
import 's2point.dart';
export 's2point.dart';
import 's2latlng.dart';
import 'util/bits/bits.dart';
import 'mutableinteger.dart';

const int _kFaceBits = 3;
const int _kNumFaces = 6;
const int _kMaxLevel = MAX_LEVEL; // Valid levels: 0..kMaxLevel
const int _kPosBits = 2 * _kMaxLevel + 1;
const int _kMaxSize = 1 << _kMaxLevel;

const int _kSwapMask = 0x01;
const int _kInvertMask = 0x02;
const int _kLookupBits = 4;
Uint16List _lookupPos = new Uint16List(1 << (2 * _kLookupBits + 2));
Uint16List _lookupIJ = new Uint16List(1 << (2 * _kLookupBits + 2));

void _initLookupCell(
    int level, int i, int j, int origOrientation, int pos, int orientation) {
  if (level == _kLookupBits) {
    int ij = (i << _kLookupBits) + j;
    _lookupPos[(ij << 2) + origOrientation] = (pos << 2) + orientation;
    _lookupIJ[(pos << 2) + origOrientation] = (ij << 2) + orientation;
  } else {
    level++;
    i <<= 1;
    j <<= 1;
    pos <<= 2;
    List<int> r = kPosToIJ[orientation];
    _initLookupCell(level, i + (r[0] >> 1), j + (r[0] & 1), origOrientation,
        pos, orientation ^ kPosToOrientation[0]);
    _initLookupCell(level, i + (r[1] >> 1), j + (r[1] & 1), origOrientation,
        pos + 1, orientation ^ kPosToOrientation[1]);
    _initLookupCell(level, i + (r[2] >> 1), j + (r[2] & 1), origOrientation,
        pos + 2, orientation ^ kPosToOrientation[2]);
    _initLookupCell(level, i + (r[3] >> 1), j + (r[3] & 1), origOrientation,
        pos + 3, orientation ^ kPosToOrientation[3]);
  }
}

bool _flag = false;

void _maybeInit() {
  if (!_flag) {
    _flag = true;
    _initLookupCell(0, 0, 0, 0, 0, 0);
    _initLookupCell(0, 0, 0, kSwapMask, 0, kSwapMask);
    _initLookupCell(0, 0, 0, kInvertMask, 0, kInvertMask);
    _initLookupCell(
        0, 0, 0, kSwapMask | kInvertMask, 0, kSwapMask | kInvertMask);
  }
}

int _lsbForLevel(int level) {
  return 1 << (2 * (_kMaxLevel - level));
}

// need s2sphere.RegionCoverer

class S2CellId {
  int _id = 0;

  S2CellId(this._id);

  S2CellId.fromPoint(S2Point p) {
    int face = S2Projections.xyzToFace(p);
    var uv = S2Projections.faceXyzToUv(face, p);
    int i = stToIJ(S2Projections.uvToST(uv.x));
    int j = stToIJ(S2Projections.uvToST(uv.y));
    _id = new S2CellId.fromFaceIJ(face, i, j).id;
  }

  S2CellId.fromFace(int face) : _id = (face << _kPosBits) + _lsbForLevel(0) {}

  S2CellId.fromLatLng(S2LatLng latLng)
      : _id = new S2CellId.fromPoint(latLng.toPoint())._id {}

  S2CellId.fromFaceIJ(int face, int i, int j) {
    // Initialization if not done yet
    _maybeInit();

    // Optimization notes:
    //  - Non-overlapping bit fields can be combined with either "+" or "|".
    //    Generally "+" seems to produce better code, but not always.

    // Note that this value gets shifted one bit to the left at the end
    // of the function.
    int n = face << (_kPosBits - 1);

    // Alternating faces have opposite Hilbert curve orientations; this
    // is necessary in order for all faces to have a right-handed
    // coordinate system.
    int bits = (face & kSwapMask);

    // Each iteration maps 4 bits of "i" and "j" into 8 bits of the Hilbert
    // curve position.  The lookup table transforms a 10-bit key of the form
    // "iiiijjjjoo" to a 10-bit value of the form "ppppppppoo", where the
    // letters [ijpo] denote bits of "i", "j", Hilbert curve position, and
    // Hilbert curve orientation respectively.
    for (int k = 7; k >= 0; --k) {
      int mask = (1 << _kLookupBits) - 1;
      bits += ((i >> (k * _kLookupBits)) & mask) << (_kLookupBits + 2);
      bits += ((j >> (k * _kLookupBits)) & mask) << 2;
      bits = _lookupPos[bits];
      n |= (bits >> 2) << ((k) * 2 * _kLookupBits);
      bits &= (kSwapMask | kInvertMask);
    }

    _id = n * 2 + 1;
  }

  // Print the num_digits low order hex digits.
  String hexFormatString(int val, int numDigits) {
    // StringBuffer result = new StringBuffer(); // (numDigits, ' ');
    List<int> result = new List<int>.filled(numDigits, ' '.codeUnitAt(0));
    for (; numDigits-- > 0; val >>= 4)
      result[numDigits] = "0123456789abcdef".codeUnitAt(val & 0xF);
    return new String.fromCharCodes(result);
  }

  String toToken() {
    // Simple implementation: print the id in hex without trailing zeros.
    // Using hex has the advantage that the tokens are case-insensitive, all
    // characters are alphanumeric, no characters require any special escaping
    // in queries for most indexing systems, and it's easy to compare cell
    // tokens against the feature ids of the corresponding features.
    //
    // Using base 64 would produce slightly shorter tokens, but for typical cell
    // sizes used during indexing (up to level 15 or so) the average savings
    // would be less than 2 bytes per cell which doesn't seem worth it.

    // "0" with trailing 0s stripped is the empty string, which is not a
    // reasonable token.  Encode as "X".
    if (_id == 0) return "X";
    int numZeroDigits = findLSBSetNonZero64(_id) ~/ 4;
    int shift = (4 * numZeroDigits);
    return hexFormatString(
        (_id >> shift) & ((1 << (64 - shift)) - 1), 16 - numZeroDigits);
  }

  S2CellId next([int level]) {
    level = level ?? this.level;
    int newId = 0;

    bool carry = true;
    for (int cursorLevel = level; cursorLevel >= 0; cursorLevel--) {
      int shift = (60 - cursorLevel * 2);
      int cursorLevelVal = (_id >> shift) & 3;
      if (carry) {
        cursorLevelVal = (cursorLevelVal + 1) % 4;
        carry = cursorLevelVal == 0;
      }
      newId |= cursorLevelVal << shift;
    }
    // set face
    newId |= (_id >> 61 & 7) << 61;
    return S2CellId(newId);
  }

  S2CellId prev([int level]) {
    level = level ?? this.level;
    int newId = 0;

    bool carry = true;
    for (int cursorLevel = level; cursorLevel >= 0; cursorLevel--) {
      int shift = (60 - cursorLevel * 2);
      int cursorLevelVal = (_id >> shift) & 3;
      if (carry) {
        cursorLevelVal = cursorLevelVal - 1;
        if (cursorLevelVal == -1) {
          cursorLevelVal = 3;
        }
        carry = cursorLevelVal == 3;
      }
      newId |= cursorLevelVal << shift;
    }
    // set face
    newId |= (_id >> 61 & 7) << 61;
    return S2CellId(newId);
  }

  int cellChildAtLevel(int level) {
    return (_id >> (60 - level * 2)) & 3;
  }

  String myHackyString() {
    // Simple implementation: print the id in hex without trailing zeros.
    // Using hex has the advantage that the tokens are case-insensitive, all
    // characters are alphanumeric, no characters require any special escaping
    // in queries for most indexing systems, and it's easy to compare cell
    // tokens against the feature ids of the corresponding features.
    //
    // Using base 64 would produce slightly shorter tokens, but for typical cell
    // sizes used during indexing (up to level 15 or so) the average savings
    // would be less than 2 bytes per cell which doesn't seem worth it.

    // "0" with trailing 0s stripped is the empty string, which is not a
    // reasonable token.  Encode as "X".
    String result = "";
    int face = _id >> 61 & 7;
    result += "F:${face} ";
    for (int depth = 0; depth < 30; depth++) {
      int depthCell = (_id >> (60 - depth * 2)) & 3;
      result += "${depth}:${depthCell == 0 ? "_" : depthCell} ";
    }
    return result;
  }

  // lsbForLevel returns the lowest-numbered bit that is on for cells at the given level.
  // func lsbForLevel(level int) uint64 { return 1 << uint64(2*(maxLevel-level)) }

  // Parent returns the cell at the given level, which must be no greater than the current level.
  S2CellId parent([int level]) {
    int newLsb = lowestOnBitForLevel(level);
    return new S2CellId((id & -newLsb) | newLsb);

    //  int shift = (30 - level) * 2;
    //   return new S2CellId((_id >> shift) << shift);
  }

// Parent returns the cell at the given level, which must be no greater than the current level.
  S2CellId myHackyParent([int level]) {
    int shift = (30 - level) * 2;
    return new S2CellId((_id >> shift) << shift);
  }

  /**
   * Return the lowest-numbered bit that is on for this cell id, which is equal
   * to (uint64(1) << (2 * (MAX_LEVEL - level))). So for example, a.lsb() <=
   * b.lsb() if and only if a.level() >= b.level(), but the first test is more
   * efficient.
   */
  int lowestOnBitForLevel(int level) {
    return 1 << (2 * (_kMaxLevel - level));
  }

  // isFace returns whether this is a top-level (face) cell.
  bool isFace() {
    return _id & (_lsbForLevel(0) - 1) == 0;
  }

  // lsb returns the least significant bit that is set.
  int lsb() {
    return _id & -_id;
  }

  S2CellId.fromFaceIJWrap(int face, int i, int j) {
    // Convert i and j to the coordinates of a leaf cell just beyond the
    // boundary of this face.  This prevents 32-bit overflow in the case
    // of finding the neighbors of a face cell.
    i = max(-1, min(_kMaxSize, i));
    j = max(-1, min(_kMaxSize, j));

    // We want to wrap these coordinates onto the appropriate adjacent face.
    // The easiest way to do this is to convert the (i,j) coordinates to (x,y,z)
    // (which yields a point outside the normal face boundary), and then call
    // S2::XYZtoFaceUV() to project back onto the correct face.
    //
    // The code below converts (i,j) to (si,ti), and then (si,ti) to (u,v) using
    // the linear projection (u=2*s-1 and v=2*t-1).  (The code further below
    // converts back using the inverse projection, s=0.5*(u+1) and t=0.5*(v+1).
    // Any projection would work here, so we use the simplest.)  We also clamp
    // the (u,v) coordinates so that the point is barely outside the
    // [-1,1]x[-1,1] face rectangle, since otherwise the reprojection step
    // (which divides by the new z coordinate) might change the other
    // coordinates enough so that we end up in the wrong leaf cell.
    double kScale = 1.0 / _kMaxSize;
    Uint8List buffer = new Uint8List(8);
    buffer.buffer.asFloat64List()[0] = 1.0;
    ++buffer.buffer.asUint64List()[0];
    double kLimit = buffer.buffer.asFloat64List()[0];
    // The arithmetic below is designed to avoid 32-bit integer overflows.
    assert(0 == _kMaxSize % 2);
    double u =
        max(-kLimit, min(kLimit, kScale * (2 * (i - _kMaxSize / 2) + 1)));
    double v =
        max(-kLimit, min(kLimit, kScale * (2 * (j - _kMaxSize / 2) + 1)));

    // Find the leaf cell coordinates on the adjacent face, and convert
    // them to a cell id at the appropriate level.
    S2Point p = S2Projections.faceUvToXyz(face, u, v);
    int face2 = S2Projections.xyzToFace(p);
    var uv2 = S2Projections.faceXyzToUv(face, p);
    _id = new S2CellId.fromFaceIJ(
            face2, stToIJ(0.5 * (uv2.x + 1)), stToIJ(0.5 * (uv2.y + 1)))
        ._id;
  }

  S2CellId.fromFaceIJSame(int face, int i, int j, bool same_face) {
    if (same_face)
      _id = new S2CellId.fromFaceIJ(face, i, j)._id;
    else
      _id = new S2CellId.fromFaceIJWrap(face, i, j)._id;
  }

  int get face {
    return (_id >> 61) & 7;
  }

  int toFaceIJOrientation(
      MutableInteger pi, MutableInteger pj, MutableInteger orientation) {
    // System.out.println("Entering toFaceIjorientation");
    int face = this.face;
    int bits = (face & _kSwapMask);

    // System.out.println("face = " + face + " bits = " + bits);

    // Each iteration maps 8 bits of the Hilbert curve position into
    // 4 bits of "i" and "j". The lookup table transforms a key of the
    // form "ppppppppoo" to a value of the form "iiiijjjjoo", where the
    // letters [ijpo] represents bits of "i", "j", the Hilbert curve
    // position, and the Hilbert curve orientation respectively.
    //
    // On the first iteration we need to be careful to clear out the bits
    // representing the cube face.
    for (int k = 7; k >= 0; --k) {
      bits = getBits1(pi, pj, k, bits);
      // System.out.println("pi = " + pi + " pj= " + pj + " bits = " + bits);
    }

    if (orientation != null) {
      // The position of a non-leaf cell at level "n" consists of a prefix of
      // 2*n bits that identifies the cell, followed by a suffix of
      // 2*(MAX_LEVEL-n)+1 bits of the form 10*. If n==MAX_LEVEL, the suffix is
      // just "1" and has no effect. Otherwise, it consists of "10", followed
      // by (MAX_LEVEL-n-1) repetitions of "00", followed by "0". The "10" has
      // no effect, while each occurrence of "00" has the effect of reversing
      // the kSwapMask bit.
      // assert (S2.POS_TO_ORIENTATION[2] == 0);
      // assert (S2.POS_TO_ORIENTATION[0] == S2.SWAP_MASK);
      if ((lowestOnBit & 0x1111111111111110) != 0) {
        bits ^= _kSwapMask;
      }
      orientation.value = bits;
    }
    return face;
  }

  S2LatLng toLatLng() {
    return S2LatLng.fromPoint(toPointRaw());
  }

  int get lowestOnBit {
    return _id & -_id;
  }

  int getBits1(MutableInteger i, MutableInteger j, int k, int bits) {
    final int nbits = (k == 7) ? (_kMaxLevel - 7 * _kLookupBits) : _kLookupBits;

    bits +=
        (((id >> (k * 2 * _kLookupBits + 1)) & ((1 << (2 * nbits)) - 1))) << 2;
    /*
     * System.out.println("id is: " + id_); System.out.println("bits is " +
     * bits); System.out.println("lookup_ij[bits] is " + lookup_ij[bits]);
     */
    bits = _lookupIJ[bits];
    i.value = (i.value + ((bits >> (_kLookupBits + 2)) << (k * _kLookupBits)));
    /*
     * System.out.println("left is " + ((bits >> 2) & ((1 << kLookupBits) -
     * 1))); System.out.println("right is " + (k * kLookupBits));
     * System.out.println("j is: " + j.value); System.out.println("addition
     * is: " + ((((bits >> 2) & ((1 << kLookupBits) - 1))) << (k *
     * kLookupBits)));
     */
    j.value = (j.value +
        ((((bits >> 2) & ((1 << _kLookupBits) - 1))) << (k * _kLookupBits)));
    bits &= (_kSwapMask | _kInvertMask);
    return bits;
  }

  S2Point toPointRaw() {
    // First we compute the discrete (i,j) coordinates of a leaf cell contained
    // within the given cell. Given that cells are represented by the Hilbert
    // curve position corresponding at their center, it turns out that the cell
    // returned by ToFaceIJOrientation is always one of two leaf cells closest
    // to the center of the cell (unless the given cell is a leaf cell itself,
    // in which case there is only one possibility).
    //
    // Given a cell of size s >= 2 (i.e. not a leaf cell), and letting (imin,
    // jmin) be the coordinates of its lower left-hand corner, the leaf cell
    // returned by ToFaceIJOrientation() is either (imin + s/2, jmin + s/2)
    // (imin + s/2 - 1, jmin + s/2 - 1). We can distinguish these two cases by
    // looking at the low bit of "i" or "j". In the first case the low bit is
    // zero, unless s == 2 (i.e. the level just above leaf cells) in which case
    // the low bit is one.
    //
    // The following calculation converts (i,j) to the (si,ti) coordinates of
    // the cell center. (We need to multiply the coordinates by a factor of 2
    // so that the center of leaf cells can be represented exactly.)

    MutableInteger i = new MutableInteger(0);
    MutableInteger j = new MutableInteger(0);
    int face = toFaceIJOrientation(i, j, null);
    // return faceSiTiToXYZ(face, i.value, j.value);

    // System.out.println("i= " + i.value + " j = " + j.value);
    int delta = isLeaf ? 1 : (((i.value ^ ((id) >> 2)) & 1) != 0) ? 2 : 0;
    int si = (i.value << 1) + delta - _kMaxSize;
    int ti = (j.value << 1) + delta - _kMaxSize;
    return faceSiTiToXYZ(face, si, ti);
  }

  /**
   * Convert (face, si, ti) coordinates (see s2.h) to a direction vector (not
   * necessarily unit length).
   */
  static S2Point faceSiTiToXYZ(int face, int si, int ti) {
    final double kScale = 1.0 / _kMaxSize;
    double u = stToUV(kScale * si);
    double v = stToUV(kScale * ti);
    return faceUvToXyz(face, u, v);
  }

  static double stToUV(double s) {
    if (s >= 0.0) {
      return (1.0 / 3.0) * ((1 + s) * (1 + s) - 1);
    } else {
      return (1.0 / 3.0) * (1 - (1 - s) * (1 - s));
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

  /**
   * Return true if this is a leaf cell (more efficient than checking whether
   * level() == MAX_LEVEL).
   */
  bool get isLeaf {
    return (_id & 1) != 0;
  }

  List<S2CellId> get edgeNeighbors {
    var neighbors = List<S2CellId>();
    MutableInteger i = new MutableInteger(0);
    MutableInteger j = new MutableInteger(0);

    int level = this.level;
    int size = 1 << (MAX_LEVEL - level);
    int face = toFaceIJOrientation(i, j, null);

    // Edges 0, 1, 2, 3 are in the S, E, N, W directions.
    neighbors.add(S2CellId.fromFaceIJSame(
            face, i.value, j.value - size, j.value - size >= 0)
        .parent(level));
    neighbors.add(S2CellId.fromFaceIJSame(
            face, i.value + size, j.value, i.value + size < MAX_SIZE)
        .parent(level));
    neighbors.add(S2CellId.fromFaceIJSame(
            face, i.value, j.value + size, j.value + size < MAX_SIZE)
        .parent(level));
    neighbors.add(S2CellId.fromFaceIJSame(
            face, i.value - size, j.value, i.value - size >= 0)
        .parent(level));
    return neighbors;
  }

  int get level {
    return _kMaxLevel - (findLSBSetNonZero64(_id) >> 1);
  }

  int get id {
    return _id;
  }

  @override
  int get hashCode {
    return _id;
  }

  @override
  bool operator ==(Object other) {
    S2CellId cellId = other;
    return _id == cellId._id;
  }

  bool operator <(Object other) {
    // Unsigned comparison
    S2CellId cellId = other;
    if (_id > 0 == cellId._id > 0) {
      return _id < cellId._id;
    }
    return _id > 0;
  }

  bool operator >(Object other) {
    // Unsigned comparison
    S2CellId cellId = other;
    if (_id > 0 == cellId._id > 0) {
      return _id > cellId._id;
    }
    return _id < 0;
  }

  String toString() {
    return "s2cellId[level: $level, id$id]";
  }
}
