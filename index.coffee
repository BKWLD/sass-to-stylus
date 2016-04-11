###
Walkthrough sass directory tree and convert sass and compass code to styl and
autoprefixer
###

# Deps
dive = require 'dive' # https://github.com/pvorb/node-dive
jsdiff = require 'diff' # https://github.com/kpdecker/jsdiff
require 'colors'
fs = require 'fs'

# Get list of css3 properties to look for. These were adapted from list on
# http://www.quackit.com/css/css3/properties/
css3 = require './css3.json'

# Start walking
dive "#{process.cwd()}/app/sass", (err, file) ->

	# Just sass files
	return unless file.match /\.scss$/

	# Get the source
	# https://regex101.com/r/bF7hN7/2
	original = fs.readFileSync file, encoding: 'utf8'

	# Apply transformations
	modified = transform original

	# Show diff
	process.stderr.write "\n\n"+file.replace(process.cwd(), '').bold.yellow+"\n\n"
	jsdiff.diffLines(original, modified).forEach (part) ->
		color = if part.added then 'green' else if part.removed then 'red' else 'grey'
		process.stderr.write part.value[color]

# Transfrom sass to stylus
transform = (source) ->

	# Remove compass imports
	source = source.replace /@import ("|')compass.+;\n?/g, ''

	# Remove imports of common, ruby-dependent, external libs
	# https://regex101.com/r/bR4oX2/2
	libs = [ 'rgbapng', 'ceaser-easing' ].join('|')
	regex = new RegExp "@import (\"|')(#{libs})\\1;\n?", 'g'
	source = source.replace(regex, '')

	# Replace CSS3 vendor prefixing mixins with simple CSS3 properties in
	# expectation  of autoprexier handling vendor prefixing.
	# https://regex101.com/r/jW7fX4/1
	regex = new RegExp "@include (#{css3.join('|')})\\((.+)\\);", 'g'
	source = source.replace regex, '$1: $2;'

	# Change sass rem calls to use stylus func
	# https://regex101.com/r/sP7eZ5/1
	source = source.replace /@include rem\((.+),\s*(.+)\)/g, '$1: rem($2)'

	# Change sass rem calls to use stylus func
	# https://regex101.com/r/sP7eZ5/1
	source = source.replace /@include rem\((.+),\s*(.+)\)/g, '$1: rem($2)'

	# Change sass default argument colons to equals
	# https://regex101.com/r/zM8yF4/1
	regex = /@mixin .*\((.*)\)/g
	while (result = regex.exec(source)) != null
		mixin = result[0].replace /:/g, '='
		source = source.slice(0, result.index) + mixin + source.slice(regex.lastIndex)

	# Change mixin defitions to stylus
	# https://regex101.com/r/bL1uB0/2
	source = source.replace /@mixin ([\w\-]+)\((.*)\)/g, '$1($2)'

	# Support how blocks get passed to yielding stylus funcs
	# https://regex101.com/r/zZ0bZ1/1
	source = source.replace /@include (.*\(.*\)\s*){/g, '+$1('

	# Change normal mixin calls
	# https://regex101.com/r/lO6yB0/2
	source = source.replace /@include (.*)\(/g, '$1('

	# Update conditionals
	# https://regex101.com/r/rY6vX6/1
	source = source.replace /@(if|else)/g, '$1'
