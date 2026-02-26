import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/services/utils.dart';

/// SimplePage with a form and built in validation and confirmation to discard changes if any are made
class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    required this.changed,
    this.hideSave = false,
    this.alwaysShowSave = false,
    this.scrollController,
    this.trailingActions,
  });

  final String title;
  final Function onSave;
  final Widget child;
  final ScrollController? scrollController;

  /// If you need the page to progress to a certain point before saving, control it here
  final bool hideSave;

  /// Useful if you have a non form field that can change, overrides the internal changed state if true
  final bool changed;

  /// When true, show the save button even if no changes have been made
  final bool alwaysShowSave;

  /// Additional trailing actions to show in the nav bar (before the save button)
  final List<Widget>? trailingActions;

  @override
  FormPageState createState() => FormPageState();
}

class FormPageState extends State<FormPage> {
  var changed = false;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    changed = widget.changed || changed;

    return PopScope<Object?>(
      canPop: !changed,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final NavigatorState navigator = Navigator.of(context);

        Utils.confirmDelete(
          context,
          'Discard changes?',
          () {
            navigator.pop();
          },
          deleteLabel: 'Yes',
          cancelLabel: 'No',
        );
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
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildLeader(BuildContext context) {
    return Utils.leadingBackWidget(
      context,
      label: changed ? 'Cancel' : 'Back',
      onPressed: () {
        if (changed) {
          Utils.confirmDelete(
            context,
            'Discard changes?',
            () {
              changed = false;
              Navigator.pop(context);
            },
            deleteLabel: 'Yes',
            cancelLabel: 'No',
          );
        } else {
          Navigator.pop(context);
        }
      },
    );
  }

  List<Widget> _buildTrailer(BuildContext context) {
    final extra = widget.trailingActions ?? [];

    if (widget.hideSave || (!changed && !widget.alwaysShowSave)) {
      return extra;
    }

    return [
      ...extra,
      Utils.trailingSaveWidget(context, () {
        if (_formKey.currentState == null) {
          return;
        }

        if (!_formKey.currentState!.validate()) {
          return;
        }

        _formKey.currentState!.save();
        widget.onSave();
      }),
    ];
  }
}
