import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/services/utils.dart';
import '../../oss_licenses.dart';

String capitalize(String input) {
  return input[0].toUpperCase() + input.substring(1);
}

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: const Text("Licences"),
      scrollable: SimpleScrollable.none,
      child: ListView.builder(
        itemCount: allDependencies.length,
        itemBuilder: (_, index) {
          var dep = allDependencies[index];
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: Utils.configItemBackground(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                  onTap: () {
                    Utils.openPage(
                      context,
                      (_) => LicenceDetailPage(
                        title: capitalize(dep.name),
                        licence: dep.license!,
                      ),
                    );
                  },
                  title: Text(
                    capitalize(dep.name),
                  ),
                  subtitle: Text(dep.description),
                  trailing: Icon(CupertinoIcons.forward,
                      color: CupertinoColors.placeholderText.resolveFrom(context), size: 18)),
            ),
          );
        },
      ),
    );
  }
}

//detail page for the licence
class LicenceDetailPage extends StatelessWidget {
  final String title, licence;
  const LicenceDetailPage({super.key, required this.title, required this.licence});

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: Text(title),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: Utils.configItemBackground(context), borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                Text(
                  licence,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
