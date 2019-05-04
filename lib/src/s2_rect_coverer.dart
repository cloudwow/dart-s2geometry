import 'package:s2geometry/src/s2_cell.dart';
import 'package:s2geometry/src/s2latlng.dart';

import 's2_lat_lng_rect.dart';
import 's2cell_id.dart';
import 'dart:collection';

class S2RectCoverer {
  static void getCovering(S2LatLngRect rect, int cellLevel,
      Set<S2CellId> covering) {
    //start with center then flood fill
    var frontier = List<S2CellId>();
    var examined = HashSet<S2CellId>();
    S2CellId center = S2CellId.fromLatLng(rect.getCenter()).parent(cellLevel);
    frontier.add(center);
    covering.add(center);
    while (frontier.isNotEmpty) {
   //   print("Frontier has ${frontier.length} cells");
      S2CellId nextId = frontier.removeLast();
      for (S2CellId neighborId in nextId.edgeNeighbors) {
        if (examined.contains(neighborId)) {
          continue;
        }
        examined.add(neighborId);
        var neighborCell = S2Cell(id: neighborId);
        var neighborRect = neighborCell.getRectBound();
        if (rect.intersects(neighborRect)) {
          covering.add(neighborId);
          frontier.add(neighborId);
        }
      }
    }
  }
}
