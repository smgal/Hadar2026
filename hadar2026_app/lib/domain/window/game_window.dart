import 'package:flutter/foundation.dart';

abstract class HDWindow extends ChangeNotifier {
  int x = 0;
  int y = 0;
  int w = 0;
  int h = 0;
  bool isVisible = false;

  void setRegion(int x, int y, int w, int h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    notifyListeners();
  }

  void show() {
    if (!isVisible) {
      isVisible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (isVisible) {
      isVisible = false;
      notifyListeners();
    }
  }

  // To be implemented by subclasses if they have specific data to update
  void update() {}
}
