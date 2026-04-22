import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedDatabase() async {
  final db = FirebaseFirestore.instance;
  
  // Check if already seeded
  final snapshot = await db.collection('restaurants').limit(1).get();
  if (snapshot.docs.isNotEmpty) {
    print('Database already seeded!');
    return;
  }

  print('Seeding database...');
  
  // 1. Campus Diner
  final dinerRef = await db.collection('restaurants').add({
    'name': 'Campus Diner',
    'location': 'Central Plaza',
    'opening_hours': '08:00 - 20:00',
    'diet_type': 'Both',
    'image_url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80'
  });
  
  await db.collection('restaurants').doc(dinerRef.id).collection('menuItems').add({
    'item_name': 'Cheese Burger',
    'price': 5.0,
    'available': true,
  });
  await db.collection('restaurants').doc(dinerRef.id).collection('menuItems').add({
    'item_name': 'French Fries',
    'price': 2.5,
    'available': true,
  });

  // 2. Green Bowl
  final bowlRef = await db.collection('restaurants').add({
    'name': 'Green Bowl',
    'location': 'Science Block',
    'opening_hours': '09:00 - 18:00',
    'diet_type': 'Veg',
    'image_url': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80'
  });

  await db.collection('restaurants').doc(bowlRef.id).collection('menuItems').add({
    'item_name': 'Quinoa Salad',
    'price': 7.0,
    'available': true,
  });
  await db.collection('restaurants').doc(bowlRef.id).collection('menuItems').add({
    'item_name': 'Avocado Toast',
    'price': 4.5,
    'available': true,
  });

  // 3. Meat Lovers
  final meatRef = await db.collection('restaurants').add({
    'name': 'Meat Lovers Grille',
    'location': 'East Wing',
    'opening_hours': '11:00 - 22:00',
    'diet_type': 'Non-Veg',
    'image_url': 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=600&q=80'
  });

  await db.collection('restaurants').doc(meatRef.id).collection('menuItems').add({
    'item_name': 'BBQ Ribs',
    'price': 12.0,
    'available': true,
  });
  await db.collection('restaurants').doc(meatRef.id).collection('menuItems').add({
    'item_name': 'Chicken Wings',
    'price': 8.0,
    'available': true,
  });

  print('Database seeded successfully!');
}
