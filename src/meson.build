leaftop_sources = [
  'config.vapi',
  'main.vala',
  'application.vala',
  'window.vala',
  'process.vala',
  'process_watcher.vala',
  'process_name_cell.vala',
  'chart_widget.vala',
  'chart_button.vala',
  'utils.vala',
]

leaftop_sources += gnome.compile_resources('leaftop-resources',
  'leaftop.gresource.xml',
  c_name: 'leaftop'
)

leaftop_deps = [
  dependency('gtk4', version:'>=4.10'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
  meson.get_compiler('vala').find_library('posix')
]

conf_data = configuration_data()
conf_data.set_quoted('LEAFTOP_VERSION',    meson.project_version())
conf_data.set_quoted('LEAFTOP_LOCALE_DIR', get_option('prefix') / get_option('localedir'))
configure_file(
  output: 'config.h',
  configuration: conf_data
)

executable('leaftop', leaftop_sources,
  c_args: [
    '-DGETTEXT_PACKAGE="leaftop"' 
  ],
  dependencies: leaftop_deps,
       install: true,
)
