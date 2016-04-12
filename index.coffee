###
Walkthrough sass directory tree and convert sass and compass code to styl and
autoprefixer
###

# Deps
dive = require 'dive'
jsdiff = require 'diff'
mkdirp = require 'mkdirp'
require 'colors'
fs = require 'fs'
getDirName = require('path').dirname

# Shorthand for logging to output
output = process.stderr.write

# Get list of css3 properties to look for. These were adapted from list on
# http://www.quackit.com/css/css3/properties/
css3 = require './css3.json'
transforms = require './transforms.json'

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
	process.stderr.write "\n"+file.replace(process.cwd(), '').bold.yellow+"\n"
	jsdiff.diffLines(original, modified).forEach (part) ->
		color = if part.added then 'green' else if part.removed then 'red' else 'grey'
		process.stderr.write part.value[color]

	# Save the modified version out
	if '--save' in process.argv

		# Log about the file
		# https://regex101.com/r/pO0mX3/1
		stylFile = file.replace /(.*\/app\/)sass(.*\/)_?(.*\.)scss/i, '$1styles$2$3styl'
		relStylFile = stylFile.replace(process.cwd(), '')
		process.stderr.write "\n💾  #{relStylFile}".bgYellow.black.bold+"\n"

		# Write the file
		mkdirp.sync getDirName stylFile
		fs.writeFileSync stylFile, modified

# Transfrom sass to stylus
transform = (source) ->

	# Remove compass imports
	source = source.replace /@import ("|')compass.+;\n?/g, ''

	# Remove imports of common, ruby-dependent, external libs
	# https://regex101.com/r/bR4oX2/2
	libs = [ 'rgbapng', 'ceaser-easing' ].join('|')
	regex = new RegExp "@import (\"|')(#{libs})\\1;\n?", 'g'
	source = source.replace(regex, '')

	# Unpack transform shorthands
	# https://regex101.com/r/mP2xG2/2
	regex = new RegExp "@include (#{transforms.join('|')})\\(", 'g'
	source = source.replace regex, 'transform: $1'

	# Replace CSS3 vendor prefixing mixins with simple CSS3 properties in
	# expectation  of autoprexier handling vendor prefixing.
	# https://regex101.com/r/jW7fX4/1
	regex = new RegExp "@include (#{css3.join('|')})\\((.+)\\);", 'g'
	source = source.replace regex, '$1: $2;'

	# Change sass rem calls to use stylus func
	# https://regex101.com/r/sP7eZ5/2
	source = source.replace /@include rem\(['"]?([\w\-]+)['"]?,\s*(.+)\)/g, '$1: rem($2)'

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
	source = source.replace /@include (.*\(.*\)\s*){/g, '+$1{'

	# Change normal mixin calls
	# https://regex101.com/r/lO6yB0/2
	source = source.replace /@include (.*)\(/gi, '$1('
	source = source.replace /@include ([\w\-]+)/gi, '$1()'

	# Update conditionals
	# https://regex101.com/r/rY6vX6/1
	source = source.replace /@(if|else)/gi, '$1'
	source = source.replace /elseif/gi, 'else if'

	# Fix varaible definitions
	# https://regex101.com/r/gX4hL9/1
	source = source.replace /(\$[\w\-]+\s*):/g, '$1 ='

	# Fix calc() with variables
	regex1 = /calc\(.*\)/gi # https://regex101.com/r/dL8hK6/2
	regex2 = /#{(\$[^}]+)}/gi # https://regex101.com/r/iE6gW1/1
	while (result1 = regex1.exec(source)) != null

		# Get the whole calc expression
		calc = result1[0]

		# Make an array of the variables being used
		vars = []
		vars.push("(#{result2[1]})") while (result2 = regex2.exec(calc)) != null
		continue unless vars.length

		# Substitute the variables for sprintf placeholders
		calc = calc.replace regex2, '%s'

		# Add the variables to the end of sprintf
		calc = "'#{calc}' % (#{vars.join(' ')})"

		# Replace the old calc with the new calc
		source = source.slice(0, result1.index) + calc + source.slice(regex1.lastIndex)
		regex1.lastIndex = result1.index + 1

	# Fix for loops
	# https://regex101.com/r/pV7oE0/2
	source = source.replace /@for (\$.+) from ([^\s]+) through ([^\s]+)/g, 'for $1 in $2..$3'

	# Return the modified source
	return source
