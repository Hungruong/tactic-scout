import 'package:flutter/material.dart';
import 'dart:math' show pi;
import 'dart:ui' show ImageFilter;

class ScanOverlay extends StatelessWidget {
 const ScanOverlay({super.key});

 @override
 Widget build(BuildContext context) {
   return Center(
     child: Container(
       width: MediaQuery.of(context).size.width * 0.85,
       height: 180,
       decoration: BoxDecoration(
         color: Colors.black.withOpacity(0.6),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(
           color: Colors.blue.withOpacity(0.3),
           width: 1,
         ),
       ),
       child: Stack(
         fit: StackFit.expand,
         alignment: Alignment.center,
         children: [
           // Background blur
           ClipRRect(
             borderRadius: BorderRadius.circular(20),
             child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
               child: Container(
                 color: Colors.transparent,
               ),
             ),
           ),
           
           // Center content
           Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.center,
               children: [
                 SizedBox(
                   height: 32,
                   width: 32,
                   child: CircularProgressIndicator(
                     strokeWidth: 3,
                     valueColor: AlwaysStoppedAnimation<Color>(
                       Colors.blue.shade400,
                     ),
                   ),
                 ),
                 const SizedBox(height: 24),
                 const Text(
                   "Scanning players...",
                   style: TextStyle(
                     color: Colors.white,
                     fontSize: 18,
                     fontWeight: FontWeight.w600,
                     letterSpacing: 0.5,
                   ),
                   textAlign: TextAlign.center,
                 ),
               ],
             ),
           ),

           // Corner Indicators
           ...buildCornerIndicators(),
         ],
       ),
     ),
   );
 }

 List<Widget> buildCornerIndicators() {
   return [
     _buildCorner(Alignment.topLeft, 0),
     _buildCorner(Alignment.topRight, pi / 2),
     _buildCorner(Alignment.bottomRight, pi),
     _buildCorner(Alignment.bottomLeft, -pi / 2),
   ];
 }

 Widget _buildCorner(Alignment alignment, double rotation) {
   return Align(
     alignment: alignment,
     child: Padding(
       padding: const EdgeInsets.all(12.0),
       child: CornerIndicator(
         transform: Matrix4.rotationZ(rotation),
       ),
     ),
   );
 }
}

class CornerIndicator extends StatelessWidget {
 final Matrix4? transform;

 const CornerIndicator({super.key, this.transform});

 @override
 Widget build(BuildContext context) {
   return Transform(
     transform: transform ?? Matrix4.identity(),
     child: Container(
       width: 24,
       height: 24,
       decoration: BoxDecoration(
         border: Border(
           left: BorderSide(
             color: Colors.blue.shade400,
             width: 2.5,
           ),
           top: BorderSide(
             color: Colors.blue.shade400,
             width: 2.5,
           ),
         ),
       ),
     ),
   );
 }
}