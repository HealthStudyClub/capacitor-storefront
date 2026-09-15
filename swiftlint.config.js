// node-swiftlint (cosmiconfig) picks this up. Extends the Ionic rule set and
// keeps SwiftPM build output out of the lint run.
const ionic = require('@ionic/swiftlint-config');

module.exports = {
  ...ionic,
  excluded: [...ionic.excluded, '${PWD}/.build', '${PWD}/build'],
};
