### Database 

A helper class, functionally replaces the DAO in legacy versions of Bipio.

	events = require 'events'
	db = require 'rethinkdb'
	fs = require 'fs'
	Q = require 'q'

	class Database extends events.EventEmitter

		constructor: (@options) ->
			self = @

			db.connect @options, (err, connection) ->
				if err
					throw new Error err
				else
					self.connection = connection
					db.dbList().run self.connection, (err, result) ->
						if result.indexOf('bipio') < 0
							db.dbCreate('bipio').run self.connection, (err, results) ->
								throw new Error err if err
								self.createTables()
						else 
							self.createTables()

			self

###### `createTables`

Creates tables based on the contents of [Models folder](../models). Bypasses if table exists already.

		createTables: () ->
			self = @
			promises = []
			db.tableList().run self.connection, (err, tables) ->
				throw new Error err if err

				for model in fs.readdirSync(path.join(__dirname, "../models")) when model isnt 'index.litcoffee'
					tableName = model.replace ".litcoffee", ""
					d = Q.defer()
					
					if tables.indexOf(tableName) < 0
						
						db.tableCreate(tableName).run self.connection, (err, results) ->
							throw new Error err if err
							console.log "Created table `#{results.config_changes[0].new_val.name}` in db `#{results.config_changes[0].new_val.db}`"
							d.reject err if err
							d.resolve results

					else
						d.resolve true

					promises.push d.promise

				Q.all(promises).then (results) ->
					self.emit "ready"

###### `get`

Retrieves an entry from the DB.

		get: (modelName, id, next) ->
			self = @
			deferred = Q.defer()

			callback = (err, cursor) ->
				if err
					throw new Error err
				else
					cursor.toArray (err, batch) ->
						if err
							throw new Error err
						else
							result = JSON.stringify batch, null, 2
							next null, result if next
							deferred.resolve result

			if id
				db.table(modelName).get(id).run self.connection, (err, result) -> 
					next null, result if next
					deferred.resolve result
			else
				db.table(modelName).run self.connection, callback

			deferred.promise

###### `save`

Saves an entry to the DB.

		insert: (modelName, object, options, next) ->
			self = @
			deferred = Q.defer()
			
			db.table(modelName).insert(object, options).run self.connection, (err, result) ->
				if err
					throw new Error err
				else if result.inserted is not 1
					throw new Error "Document not inserted"
				else
					next null, result.changes[0].new_val if next
					deferred.resolve result.changes[0].new_val

			deferred.promise

###### `Database.update`

Updates an entry in the DB.

		update: (modelName, object, next) ->
			self = @
			deferred = Q.defer()

			db.table(modelName).get(object.id).update(object).run self.connection, (err, result) ->
				if err
					throw new Error err
				else
					next null, result.changes[0].new_val if next
					deferred.resolve result.changes[0].new_val

			deferred.promise

###### `remove`

Removes an entry from the DB.

		remove: (modelName, id, next) ->
			self = @
			deferred = Q.defer()

			db.table(modelName).get(id).delete().run self.connection, (err, result) ->
				if err
					throw new Error err
				else
					next null, result if next
					deferred.resolve result

			deferred.promise

	module.exports = Database
