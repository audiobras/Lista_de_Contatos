import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = openDatabase(
    join(await getDatabasesPath(), 'contacts_database.db'),
    onCreate: (db, version) {
      return db.execute(
        "CREATE TABLE contacts(id INTEGER PRIMARY KEY, name TEXT, phone TEXT, email TEXT, image_path TEXT)",
      );
    },
    version: 1,
  );

  runApp(MyApp(database: database));
}

class Contact {
  int? id;
  String name;
  String phone;
  String email;
  String? imagePath;

  Contact({this.id, required this.name, required this.phone, required this.email, this.imagePath});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'image_path': imagePath,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      imagePath: map['image_path'],
    );
  }

  Contact copyWith({int? id, String? name, String? phone, String? email, String? imagePath}) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class MyApp extends StatelessWidget {
  final Future<Database> database;

  MyApp({required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ContactList(database: database),
    );
  }
}

class ContactList extends StatefulWidget {
  final Future<Database> database;

  ContactList({required this.database});

  @override
  _ContactListState createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  final List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    _getContactsFromDatabase();
  }

  Future<void> _getContactsFromDatabase() async {
    final Database db = await widget.database;
    final List<Map<String, dynamic>> maps = await db.query('contacts');

    setState(() {
      contacts.clear();
      contacts.addAll(maps.map((map) => Contact.fromMap(map)));
    });
  }

  Future<void> _addContact() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) {
      return;
    }

    File image = File(pickedImage.path);

    await _insertContact(Contact(name: "Novo contato", phone: "123-456-7890", email: "teste@teste.com", imagePath: pickedImage.path));
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? takenImage = await picker.pickImage(source: ImageSource.camera);

    if (takenImage == null) {
      return;
    }

    File image = File(takenImage.path);

    await _insertContact(Contact(name: "Novo contato", phone: "123-456-7890", email: "teste@teste.com", imagePath: takenImage.path));
  }

  Future<void> _insertContact(Contact contact) async {
    final Database db = await widget.database;

    await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _getContactsFromDatabase();
  }

  Future<void> _editContact(Contact contact) async {
    final editedContact = await showDialog<Contact>(
      context: this.context,
      builder: (BuildContext context) {
        TextEditingController nameController = TextEditingController(text: contact.name);
        TextEditingController phoneController = TextEditingController(text: contact.phone);
        TextEditingController emailController = TextEditingController(text: contact.email);

        return AlertDialog(
          title: Text('Editar contato'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Fone'),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              ElevatedButton(
                onPressed: () {
                  final editedName = nameController.text;
                  final editedPhone = phoneController.text;
                  final editedEmail = emailController.text;

                  final editedContact = contact.copyWith(
                    name: editedName,
                    phone: editedPhone,
                    email: editedEmail,
                  );

                  Navigator.of(context).pop(editedContact);
                },
                child: Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );

    if (editedContact != null) {
      await _updateContact(editedContact);
    }
  }

  Future<void> _updateContact(Contact contact) async {
    final Database db = await widget.database;

    await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );

    _getContactsFromDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lista de Contatos"),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: contacts[index].imagePath != null ? FileImage(File(contacts[index].imagePath!)) : null,
            ),
            title: Text(contacts[index].name),
            subtitle: Text("Phone: ${contacts[index].phone}\nEmail: ${contacts[index].email}"),
            onTap: () {
              _editContact(contacts[index]);
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _addContact,
            child: Icon(Icons.add),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _takePicture,
            child: Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}
