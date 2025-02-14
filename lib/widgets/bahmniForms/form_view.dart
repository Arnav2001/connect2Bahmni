import 'package:connect2bahmni/screens/models/patient_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/models/form_definition.dart';
import '../../domain/models/omrs_concept.dart';
import '../../providers/meta_provider.dart';
import '../../services/forms.dart';
import '../form_fields.dart';
import '../patient_info.dart';

class ObservationForm extends StatefulWidget {
  final PatientModel patient;
  const ObservationForm({super.key, required this.patient});

  @override
  State<ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends State<ObservationForm> {
  final _formKey = GlobalKey<FormState>();
  final List<ObservationInstance> _observationInstances = [];
  bool isEditing = true;
  final String obsControlType = 'obsControl';
  final String obsGroupControlType = 'obsGroupControl';
  late Future<bool?> _formInitialized;

  static const msgEnterMandatory = 'This is a required field';
  static const imageHandler = 'ImageUrlHandler';
  static const videoHandler = 'VideoUrlHandler';


  @override
  void initState() {
    super.initState();
    FormResource form = Provider.of<MetaProvider>(context, listen: false).observationForms.firstWhere((form) => form.name.toLowerCase() == 'Vitals'.toLowerCase());
    _formInitialized = BahmniForms().fetch(form.uuid).then((value) => value.definition).then((value) => _initObservationInstances(value));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: _formInitialized,
      builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 40, child: Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator())));
        }

        if (snapshot.hasError) {
          return _initializationError(snapshot.error);
        }
        if (snapshot.hasData && snapshot.data == false) {
            return  _initializationError(null);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('Observation Form'),
          ),
          body: Padding(
            padding: EdgeInsets.all(5.0),
            child: Form(
              key: _formKey,
              child: ListView(
                //crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PatientInfo(patient: widget.patient),
                  for (var rowNum = 0; rowNum < _observationInstances.length; rowNum++)
                    Stack(
                      children: <Widget>[
                        Container(
                          margin: EdgeInsets.fromLTRB(5, 8, 5, 5),
                          padding: const EdgeInsets.all(5.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            border: Border.all(color: Colors.blueAccent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildObservationFields(_observationInstances[rowNum], rowNum),
                              SizedBox(height: 16.0),
                            ],
                          ),
                        ),
                        _buildObservationInstanceHeader(_observationInstances[rowNum], rowNum),
                        ..._buildRowActions(_observationInstances[rowNum], rowNum),
                      ],
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildFAB(),
        );
      },
    );
  }

  Scaffold _initializationError(Object? error) {
    return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: true,
              title: const Text('Observation Form'),
              elevation: 0.1,
            ),
            body: Container(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Text(error?.toString() ?? 'Error initializing form'),
              ),
            )
        );
  }

  FloatingActionButton _buildFAB() {
    if (isEditing) {
      return FloatingActionButton(
        onPressed: _submitForm,
        tooltip: 'Save',
        child: Icon(Icons.save_outlined),
      );
    }
    return FloatingActionButton(
        onPressed: () => setState(() => isEditing = true),
        tooltip: 'Edit',
        child: Icon(Icons.edit_outlined),
    );
  }

  bool _showAddMore(ControlDefinition control) {
    return control.properties!.addMore != null && control.properties!.addMore!;
  }

  Widget _buildObservationFields(ObservationInstance observationInstance, int i) {
    debugPrint('Observation Instance $i fields: ${observationInstance.fields?.length}');
    return Column(
      children: observationInstance.fields!.map((field) => _buildObservationField(field, observationInstance)).toList(),
    );
  }

  Widget _buildObservationField(ObservationField field, ObservationInstance observationInstance) {
      switch (field.dataType) {
        case ConceptDataType.text:
          return _buildTextField(field);
        case ConceptDataType.numeric:
          return _buildNumericField(field);
        case ConceptDataType.boolean:
          return _buildBooleanField(field);
        case ConceptDataType.datetime:
        case ConceptDataType.date:
          return _buildDateField(field);
        case ConceptDataType.coded:
          return _buildCodedField(field);
        case ConceptDataType.na:
            if (field.definition.type == obsGroupControlType) {
              debugPrint('building composite field');
              return _buildCompositeFields(field, observationInstance);
            }
            return SizedBox();
        case ConceptDataType.complex:
          String? conceptHandler = field.definition.concept?.conceptHandler;
          debugPrint('${field.dataType}. Handler - $conceptHandler');
          if (conceptHandler == imageHandler) {
            return _buildImageUploadField(field);
          }
          if (conceptHandler == videoHandler) {
            return _buildVideoUploadField(field);
          }
          return Container(margin: EdgeInsets.fromLTRB(0, 10, 0, 0), width: double.infinity, child: Text('This field type is not supported yet'),);
        default:
          debugPrint('Unknown data type: ${field.dataType}. can not render field');
          return Container(margin: EdgeInsets.fromLTRB(0, 10, 0, 0), width: double.infinity, child: Text('This field type is not supported yet'),);
      }
  }

  TextFormField _buildNumericField(ObservationField field) {
    return TextFormField(
          key: UniqueKey(),
          validator: field.validationRule,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '${field.label} ${field.required ? '*' : ''}',
            // enabledBorder: OutlineInputBorder(
            //   // borderSide: const BorderSide(color: Colors.blue, width: 2),
            //   borderRadius: BorderRadius.circular(20),
            // ),
            // border: OutlineInputBorder(
            //   borderSide: const BorderSide(color: Colors.blue, width: 2),
            //   borderRadius: BorderRadius.circular(20),
            // ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly
          ],
          onChanged: (value) {
            debugPrint('Saving value $value to field');
            field.value = value;
          },
          initialValue: field.value,
        );
  }

  CheckboxFormField _buildBooleanField(ObservationField field) {
    return CheckboxFormField(
          key: UniqueKey(),
          initialValue: field.value != null ? (field.value is bool ? field.value : bool.tryParse(field.value.toString(), caseSensitive: false)) : false,
          title: Text('${field.label} ${field.required ? '*' : ''}'),
          validator: (value) => field.required ? 'Required' : null,
          onSaved: (value) => field.value = value,
          enabled: isEditing,
        );
  }

  InputDatePickerFormField _buildDateField(ObservationField field) {
    DateTime currentDate = DateTime.now();
    return InputDatePickerFormField(
            key: UniqueKey(),
            fieldLabelText: field.label,
            firstDate:  DateTime(currentDate.year-100, 1, 1) ,
            lastDate: currentDate,
            onDateSaved: (value) => field.value = DateFormat('yyyy-MM-dd').format(value),
            initialDate: field.value != null ? DateTime.parse(field.value!) : null,
        );
  }

  DropDownSearchFormField<ConceptAnswerDefinition> _buildCodedField(ObservationField field) {
    return DropDownSearchFormField<ConceptAnswerDefinition>(
          hint: field.label ?? '',
          label: field.label ?? '',
          initialValue: field.value,
          itemAsString: (option) => option.displayString ?? '-unknown-',
          items: field.definition.concept?.answers ?? [],
          enabled: isEditing,
          onChanged: (value) {
            debugPrint('Saving value $value to field');
            field.value = value;
          },
          onSaved: (value) {
            field.value = value;
          },
          validator: field.validationRule,
          compareFn: (ConceptAnswerDefinition? i, ConceptAnswerDefinition? s) => i?.uuid == s?.uuid,
          filterFn: (ConceptAnswerDefinition? i, String? s) => i?.displayString?.toLowerCase().contains(s!.toLowerCase()) ?? false,
        );
  }

  TextFormField _buildTextField(ObservationField field) {
    return TextFormField(
          key: UniqueKey(),
          validator: field.validationRule,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '${field.label} ${field.required ? '*' : ''}',
            // enabledBorder: OutlineInputBorder(
            //   // borderSide: const BorderSide(color: Colors.blue, width: 2),
            //   borderRadius: BorderRadius.circular(20),
            // ),
            // border: OutlineInputBorder(
            //   borderSide: const BorderSide(color: Colors.blue, width: 2),
            //   borderRadius: BorderRadius.circular(20),
            // ),
          ),
          keyboardType: TextInputType.text,
          onChanged: (value) => field.value = value,
          initialValue: field.value,
        );
  }

  Stack _buildCompositeFields(ObservationField field, ObservationInstance observationInstance) {
    return Stack(
              children: [
                Container(
                  margin: EdgeInsets.fromLTRB(5, 15, 5, 5),
                  padding: const EdgeInsets.all(5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: Column(
                    key: UniqueKey(),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (var subField in field.subFields!)
                        _buildObservationField(subField, observationInstance),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 9,
                  child: Container(
                    padding: EdgeInsets.only(bottom: 5, left: 5, right: 5),
                    color: Colors.white,
                    child: Text(
                      field.label ?? '',
                      style: TextStyle(color: Colors.black, fontSize: 12),
                    ),
                  ),
                )
              ],
            );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Process and save the observation data here
      for (var instance in _observationInstances) {
        for (var field in instance.fields!) {
            var value = field.value ?? '';
            debugPrint('${field.label}: $value');
        }
      }

      // Clear the form fields
      //_formKey.currentState!.reset();

      // Show a success message or navigate to another screen
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Observation Submitted'),
            content: Text('Observation submitted successfully.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      setState(() {
        isEditing = false;
      });
    }
  }

  Widget _buildObservationInstanceHeader(ObservationInstance observationInstance, int rowNum) {
    String? labelText;
    if (observationInstance.definition?.type == obsGroupControlType) {
      labelText = observationInstance.definition?.label?.value;
    }
    labelText ??= '${observationInstance.fields?.first.label}';

    return Positioned(
      left: 20,
      top: 2,
      child: Container(
        padding: EdgeInsets.only(bottom: 5, left: 5, right: 5),
        color: Colors.white,
        child: Text(
          labelText,
          style: TextStyle(color: Colors.black, fontSize: 12),
        ),
      ),
    );
  }

  List<Widget> _buildRowActions(ObservationInstance obsInstance, int rowNum) {
    List<Widget> actions = [];
    var showAddMore = _showAddMore(obsInstance.definition!);
    if (showAddMore) {
      actions.add(Positioned(
        right: 40,
        top: -12,
        child: IconButton(
            color: Colors.blue,
            onPressed: () => _addObservationInstance(obsInstance, rowNum + 1),
            icon: Icon(Icons.add_circle)
        ),
      ));
    }

    if (showAddMore) {
      actions.add(Positioned(
        right: 10,
        top: -12,
        child: IconButton(
            color: Colors.blue,
            onPressed: () {
              _removeObservationInstance(obsInstance);
            },
            icon: Icon(Icons.remove_circle)
        ),
      ));
    }
    return actions;
  }

  bool _initObservationInstances(FormDefinition? formDef) {
    _observationInstances.clear();
    if (formDef == null) {
      return false;
    }
    if (formDef.controls != null) {
      var controls = formDef.controls?.where((element) => element.type == obsControlType || element.type == obsGroupControlType).toList();
      if (controls != null) {
        controls.sort((a, b) => a.position?.row.compareTo(b.position?.row ?? 0) ?? 0);
        for (ControlDefinition fieldDefinition in controls) {
          if (fieldDefinition.type == obsControlType) {
            _observationInstances.add(ObservationInstance(fields: [
              _createFieldInstance(fieldDefinition)],
              definition: fieldDefinition,
            ));
          } else if (fieldDefinition.type == obsGroupControlType) {
            var subFieldsDefinitions = fieldDefinition.controls?.where((element) => element.type == obsControlType || element.type == obsGroupControlType).toList();
            if (subFieldsDefinitions != null) {
              subFieldsDefinitions.sort((a, b) => a.position?.row.compareTo(b.position?.row ?? 0) ?? 0);
              var groupFields = <ObservationField>[];
              for (var controlDef in subFieldsDefinitions) {
                debugPrint('subcontrol type =  ${controlDef.type}');
                groupFields.add(_createFieldInstance(controlDef));
              }
              _observationInstances.add(ObservationInstance(fields: groupFields, definition: fieldDefinition));
            }
          }
        }
      }
    }
    return true;
  }

  ObservationField _createFieldInstance(ControlDefinition fieldDefinition) {
    if (fieldDefinition.isComposite) {
      var subFieldsDefinitions = fieldDefinition.controls?.where((element) => element.type == obsControlType || element.type == obsGroupControlType).toList();
      if (subFieldsDefinitions != null) {
        subFieldsDefinitions.sort((a, b) => a.position?.row.compareTo(b.position?.row ?? 0) ?? 0);
        var groupFields = <ObservationField>[];
        for (var controlDef in subFieldsDefinitions) {
          debugPrint('subcontrol type =  ${controlDef.type}');
          groupFields.add(_createFieldInstance(controlDef));
        }
        return ObservationField(
          definition: fieldDefinition,
          subFields: groupFields,
        );
      }
    }
    return ObservationField(
      definition: fieldDefinition,
      validationRule: (value) {
        var mandatory = fieldDefinition.properties?.mandatory ?? false;
        if (mandatory && value == null) {
          return msgEnterMandatory;
        }
        if (mandatory && (value is String) && value.isEmpty) {
          return msgEnterMandatory;
        }
        return null;
      },
    );
  }

  void _addObservationInstance(ObservationInstance obsInstance, int rowNum) {
    setState(() {
      _observationInstances.insert(rowNum, obsInstance.clone());
    });
  }

  void _removeObservationInstance(ObservationInstance instance) {
    setState(() {
      _observationInstances.remove(instance);
    });
  }

  Widget _buildImageUploadField(ObservationField field) {
    return Container(margin: EdgeInsets.fromLTRB(0, 10, 0, 0), width: double.infinity, child: Text('Image type is not supported yet'),);
  }

  Widget _buildVideoUploadField(ObservationField field) {
    return Container(margin: EdgeInsets.fromLTRB(0, 10, 0, 0), width: double.infinity, child: Text('Video type is not supported yet'),);
  }
}


class ObservationInstance {
  List<ObservationField>? fields;
  ControlDefinition? definition;
  ObservationInstance({this.fields, this.definition});

  ObservationInstance clone() {
    var clone = ObservationInstance(fields: fields?.map((e) => e.clone()).toList(), definition: definition);
    return clone;
  }
}


class ObservationField {
  final List<ObservationField>? subFields;
  final FormFieldValidator<dynamic>? validationRule;
  final ControlDefinition definition;
  dynamic value;

  ObservationField({
    required this.definition,
    this.subFields,
    this.validationRule,
    this.value,
  });

  bool get required => definition.properties?.mandatory ?? false;
  String? get label => definition.label?.value;
  ConceptDataType? get dataType => definition.dataType;

  ObservationField clone() {
    var clone = ObservationField(
      definition: definition,
      subFields: subFields?.map((e) => e.clone()).toList(),
      validationRule: validationRule,
    );
    return clone;
  }
}
