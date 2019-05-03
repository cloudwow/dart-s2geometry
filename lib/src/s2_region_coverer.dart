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

import 'package:s2geometry/src/s2_lat_lng_rect.dart';

/**
 * An S2RegionCoverer is a class that allows arbitrary regions to be
 * approximated as unions of cells (S2CellUnion). This is useful for
 * implementing various sorts of search and precomputation operations.
 *
 * Typical usage: {@code S2RegionCoverer coverer; coverer.setMaxCells(5); S2Cap
 * cap = S2Cap.fromAxisAngle(...); S2CellUnion covering;
 * coverer.getCovering(cap, covering); * }
 *
 * This yields a cell union of at most 5 cells that is guaranteed to cover the
 * given cap (a disc-shaped region on the sphere).
 *
 *  The approximation algorithm is not optimal but does a pretty good job in
 * practice. The output does not always use the maximum number of cells allowed,
 * both because this would not always yield a better approximation, and because
 * max_cells() is a limit on how much work is done exploring the possible
 * covering as well as a limit on the final output size.
 *
 *  One can also generate interior coverings, which are sets of cells which are
 * entirely contained within a region. Interior coverings can be empty, even for
 * non-empty regions, if there are no cells that satisfy the provided
 * constraints and are contained by the region. Note that for performance
 * reasons, it is wise to specify a max_level when computing interior coverings
 * - otherwise for regions with small or zero area, the algorithm may spend a
 * lot of time subdividing cells all the way to leaf level to try to find
 * contained cells.
 *
 *  This class is thread-unsafe. Simultaneous calls to any of the getCovering
 * methods will conflict and produce unpredictable results.
 *
 */

import 's2_lat_lng_rect.dart';
import 's2cell_id.dart';

class S2RegionCoverer {
  /**
   * Computes a list of cell ids that covers the given region and satisfies the
   * various restrictions specified above.
   *
   * @param region The region to cover
   * @param covering The list filled in by this method
   */
  void getCovering(S2LatLngRect rect, int cellLevel, List<S2CellId> covering) {}
}
