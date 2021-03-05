gulp          = require "gulp"
load_plugins  = require "gulp-load-plugins"
series        = require "run-sequence"
express       = require "express"
gm            = require "gm"
im            = gm.subClass(imageMagick: true)
yaml_config   = require "yaml-config"
del           = require "del"
fs            = require "fs"

config        = yaml_config.readConfig "config.yaml"

src           = config.source_path
lib           = config.lib_path
target        = config.target_path
index         = config.index_name

sources =
  html:     "#{src}/#{index}.jade"
  assets:   ["#{src}/*", "#{src}/.*", "!#{src}/#{index}.jade"]
  css:      ["#{src}/css/**/*.scss", "!#{src}/css/**/_*.scss"]
  js:       [
              "node_modules/smooth-scroll/dist/smooth-scroll.polyfills.js",
              "#{src}/js/**/*.js"
            ]

production = false
plugins = null
lr_server = null

gulp.task "html", ["init"], ->
  gulp.src(sources.html)
    .pipe(plugins.jade(data: config.properties))
    .pipe(gulp.dest(target))

gulp.task "assets", ->
  gulp.src(sources.assets, noDir: true)
    .pipe(gulp.dest(target))

gulp.task "favicon", (cb) ->
  size = 16
  color = config.properties.tint
  dest = "#{target}/favicon.png"
  unless fs.existsSync target
    fs.mkdirSync target
  gm(size, size, color).write dest, (err) ->
    if err
      im(size, size, color).write(dest, cb)
    else
      cb(null)

gulp.task "css", ["init"], ->
  gulp.src(sources.css)
    .pipe(plugins.sass(includePaths: [src]))
    .pipe(plugins.autoprefixer("last 2 versions"))
    .pipe(plugins.csso())
    .pipe(gulp.dest(target))

gulp.task "js", ["init"], ->
  gulp.src(sources.js)
    .pipe(plugins.uglify())
    .pipe(plugins.concat('app.js'))
    .pipe(gulp.dest(target))

gulp.task "build", ["clean"], ->
  gulp.start(["html", "assets", "favicon", "css", "js"])

gulp.task "serve", ["build"], ->
  connect_lr  = require "connect-livereload"
  lr_server = require("tiny-lr")()
  app = express()
  app.use(connect_lr())
  app.use(express.static(target))
  app.listen(config.express_port)

gulp.task "reload", ["init"], ->
  gulp.src(target, read: false)
    .pipe(plugins.livereload(lr_server))

gulp.task "open", ["init", "serve"], ->
  gulp.src(__filename)
    .pipe(plugins.open(uri: "http://localhost:#{config.express_port}/"))
  # Make it terminate immediately
  null

gulp.task "watch", ["open"], (cb) ->
  lr_server.listen config.livereload_port, (err) ->
    if err
      throw err
    gulp.watch sources.html, (event) ->
      series "html", "reload"
    gulp.watch sources.assets, (event) ->
      series "assets", "reload"
    gulp.watch "#{src}/**/*.scss", (event) ->
      series "css", "reload"
    gulp.watch sources.js, (event) ->
      series "js", "reload"

gulp.task "init", ->
  plugins = load_plugins()

gulp.task "clean", ["init"], () ->
  del(target)

gulp.task "develop", ["clean"], ->
  gulp.start "watch"

gulp.task "default", ["clean"], ->
  gulp.start "build"
