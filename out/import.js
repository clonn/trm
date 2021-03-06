var Promise, UglifyJS, VERSION, browserify, exports, fs, optUrl, path;

UglifyJS = require("uglify-js");

fs = require("fs");

path = require("path");

optUrl = process.LIB || "localhost:1337/lib/trm.compile.js";

Promise = require("bluebird");

browserify = require('browserify');

VERSION = require("../package.json").version;

module.exports = exports = {
  DEBUG: false,
  config: function(opt) {
    if (typeof opt !== "string") {
      throw "optUrl should be a string type";
    }
    this.optUrl = optUrl = opt;
    return this;
  },
  optUrl: optUrl,
  resultDisplay: function(_arg) {
    var aid, code, pid;
    code = _arg.code, pid = _arg.pid, aid = _arg.aid;
    return code + ("window.analytics.load(function () {\n  window.analytics.initial(\"" + pid + "\", \"" + aid + "\");\n  window.analytics.send(\"\");\n});");
  },
  compress: function(filepath, opt) {
    var code, file, result;
    filepath = filepath || path.join(__dirname, "./usage.js");
    optUrl = opt || optUrl;
    file = fs.readFileSync(filepath, "utf8");
    file = file.replace("{ENV_PATH}", optUrl);
    file = file.replace("{VERSION}", VERSION);
    code = file;
    result = this.compressContent(code);
    return result;
  },
  compressContent: function(content) {
    return UglifyJS.minify(content, {
      fromString: true
    });
  },
  generateLib: function(config) {
    var destPath, domain, filepath, minify, self, srcPath;
    self = this;
    domain = config.domain, destPath = config.destPath, srcPath = config.srcPath, minify = config.minify;
    filepath = srcPath || path.join(__dirname, "./trm.js");
    return new Promise(function(resolve, reject) {
      var b;
      b = browserify();
      b.add(filepath);
      return b.bundle(function(err, src) {
        var file;
        if (err) {
          return reject(err);
        }
        file = src.toString();
        file = file.replace(/{DOMAIN_NAME}/g, domain);
        if (minify) {
          file = self.compressContent(file);
          file = file.code;
        }
        if (!destPath) {
          return reject();
        }
        destPath = path.join(process.cwd(), destPath);
        self.saveFile(destPath, file);
        return resolve(file);
      });
    });
  },
  saveFile: function(destPath, content) {
    return fs.writeFileSync(destPath, content);
  }
};
