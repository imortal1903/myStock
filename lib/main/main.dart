import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/crud/viewmodels/home_viewmodel.dart';
import '../features/crud/views/home_page.dart';

main(){
  runApp(const MyStockApp());
}

class MyStockApp extends StatelessWidget {
  const MyStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
      ],
      child: MaterialApp(
        title: 'myStock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          fontFamily: 'Roboto',
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6B3FA0),
            secondary: Color(0xFFFFB830),
            surface: Color(0xFF252540),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}