###
This is like the main script except it just removes compass, thus keeping
the files as sass files.
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
		stylFile = file.replace /(.*\/app\/)sass(.*\/)_?(.*\.)scss/i, '$1styles$2$3scss'
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
	source = source.replace regex, 'transform: $1('

	# Replace CSS3 vendor prefixing mixins with simple CSS3 properties in
	# expectation  of autoprexier handling vendor prefixing.
	# https://regex101.com/r/jW7fX4/1
	regex = new RegExp "@include (#{css3.join('|')})\\((.+)\\);", 'g'
	source = source.replace regex, '$1: $2;'

	# Return the modified source
	return source
