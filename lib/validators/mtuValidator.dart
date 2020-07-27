Function mtuValidator(bool required) {
  return (String str) {
    if (str == null || str == "") {
      return required ? 'Please fill out this field' : null;
    }

    var mtu = int.tryParse(str);
    if (mtu == null || mtu < 0 || mtu > 65535) {
      return 'Please enter a valid mtu';
    }

    return null;
  };
}
