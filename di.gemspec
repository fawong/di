# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{di}
  s.version = "0.1.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Akinori MUSHA"]
  s.date = %q{2010-05-06}
  s.default_executable = %q{di}
  s.description = %q{The di(1) command wraps around GNU diff(1) to provide reasonable
default settings and some original features.
}
  s.email = %q{knu@idaemons.org}
  s.executables = ["di"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "HISTORY",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "bin/di",
     "di.gemspec",
     "lib/di.rb",
     "test/helper.rb",
     "test/test_di.rb"
  ]
  s.homepage = %q{http://github.com/knu/di}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubygems_version = %q{1.3.7.pre.1}
  s.summary = %q{A wrapper around GNU diff(1)}
  s.test_files = [
    "test/helper.rb",
     "test/test_di.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    else
      s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    end
  else
    s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
  end
end

