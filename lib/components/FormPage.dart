import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/services/utils.dart';

/// SimplePage with a form and built in validation and confirmation to discard changes if any are made
class FormPage extends StatefulWidget {
  const FormPage(
      {Key? key,
      required this.title,
      required this.child,
      required this.onSave,
      required this.changed,
      this.hideSave = false,
      this.scrollController})
      : super(key: key);

  final String title;
  final Function onSave;
  final Widget child;
  final ScrollController? scrollController;

  /// If you need the page to progress to a certain point before saving, control it here
  final bool hideSave;

  /// Useful if you have a non form field that can change, overrides the internal changed state if true
  final bool changed;

  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  var changed = false;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    changed = widget.changed || changed;

    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (didPop) {
            return;
          }
          final NavigatorState navigator = Navigator.of(context);

          Utils.confirmDelete(context, 'Discard changes?', () {
            navigator.pop();
          }, deleteLabel: 'Yes', cancelLabel: 'No');
        },
        child: SimplePage(
          leadingAction: _buildLeader(context),
          trailingActions: _buildTrailer(context),
          scrollController: widget.scrollController,
          title: Text(widget.title),
          child: Form(
              key: _formKey,
              onChanged: () => setState(() {
                    changed = true;
                  }),
              child: widget.child),
        ));
  }

  Widget _buildLeader(BuildContext context) {
    return Utils.leadingBackWidget(context, label: changed ? 'Cancel' : 'Back', onPressed: () {
      if (changed) {
        Utils.confirmDelete(context, 'Discard changes?', () {
          changed = false;
          Navigator.pop(context);
        }, deleteLabel: 'Yes', cancelLabel: 'No');
      } else {
        Navigator.pop(context);
      }
    });
  }

  List<Widget> _buildTrailer(BuildContext context) {
    if (!changed || widget.hideSave) {
      return [];
    }

    return [
      Utils.trailingSaveWidget(
        context,
        () {
          if (_formKey.currentState == null) {
            return;
          }

          if (!_formKey.currentState!.validate()) {
            return;
          }

          _formKey.currentState!.save();
          widget.onSave();
        },
      )
    ];
  }
}
