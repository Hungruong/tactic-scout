import 'package:flutter/material.dart';

class Player {
  final String name;
  final String position;
  final String avg;
  final String hrs;
  final Color teamColor;

  const Player({
    required this.name,
    required this.position,
    required this.avg,
    required this.hrs,
    required this.teamColor,
  });
}
