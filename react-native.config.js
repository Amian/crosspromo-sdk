const path = require('path');

module.exports = {
  dependency: {
    platforms: {
      ios: {},
      android: {
        sourceDir: path.join(
          __dirname,
          'packages/crosspromo-react-native/android',
        ),
        packageImportPath: 'import app.crosspromo.sdk.CrossPromoPackage;',
        packageInstance: 'new CrossPromoPackage()',
      },
    },
  },
};
