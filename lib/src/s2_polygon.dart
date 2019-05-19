import 's2latlng.dart';

class S2Polygon {
  final List<S2LatLng> latLngs;
  S2Polygon(this.latLngs) {
    if (latLngs.last != latLngs.first) {
      latLngs.add(latLngs.first);
    }
  }

  S2LatLng get center {
    double latSum = 0.0;
    double lngSum = 0.0;
    for (var ll in latLngs) {
      latSum += ll.lat.radians;
      lngSum += ll.lng.radians;
    }
    return S2LatLng.fromRadians(
        latSum / latLngs.length, lngSum / latLngs.length);
  }

  S2Polygon shrunken(double percent) {
    S2LatLng center = this.center;

    var newLatLngs = List<S2LatLng>();

    for (S2LatLng latLng in latLngs) {
      double newLat = latLng.lat.radians -
          (latLng.lat.radians - center.lat.radians) * (percent / 100.0);
      double newLng = latLng.lng.radians -
          (latLng.lng.radians - center.lng.radians) * (percent / 100.0);
      newLatLngs.add(S2LatLng.fromRadians(newLat, newLng));
    }
    return S2Polygon(newLatLngs);
  }
}
