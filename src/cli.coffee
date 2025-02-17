path = require 'path'
fs = require 'fs'
fibrous = require 'fibrous'
RegClient = require 'npm-registry-client'
_ = require 'lodash'

module.exports = fibrous (argv) ->

  [to, from] = for dir in ['to', 'from']
    url: argv[dir]
    auth:
      token: argv["#{dir}-token"]
      username: argv["#{dir}-username"]
      password: argv["#{dir}-password"]
      email: argv["#{dir}-email"]
      alwaysAuth: true
  pick_version = argv.version
  moduleNames = argv._

  unless from.url and (from.auth.token or (from.auth.username and from.auth.password)) and
         to.url and (to.auth.token or (to.auth.username and to.auth.password)) and
         moduleNames.length
    console.log 'usage: npm-copy --from <repository url> --from-token <token> --to <repository url> --to-token <token> moduleA [moduleB...]'
    return

  npm = new RegClient()

  for moduleName in argv._
    fromVersions = npm.sync.get("#{from.url}/#{moduleName}", auth: from.auth, timeout: 3000).versions
    try
      toVersions = npm.sync.get("#{to.url}/#{moduleName}", auth: to.auth, timeout: 3000).versions
    catch e
      throw e unless e.code is 'E404'
      toVersions = {}

    # versionsToSync = _.difference Object.keys(fromVersions), Object.keys(toVersions)
    # pick from pick_version
    versionsToSync = _.pick(fromVersions, pick_version)
    #show type off vars
    console.log versionsToSync

    for semver, oldMetadata of versionsToSync

      unless semver in versionsToSync
        

        {dist} = oldMetadata

        # clone the metadata skipping private properties and 'dist'
        newMetadata = {}
        newMetadata[k] = v for k, v of oldMetadata when k[0] isnt '_' and k isnt 'dist'

        remoteTarball = npm.sync.fetch dist.tarball, auth: from.auth

        try
            res = npm.sync.publish "#{to.url}/#{moduleName}", auth: to.auth, metadata: newMetadata, access: 'public', body: remoteTarball
            console.log "#{moduleName}@#{semver} cloned"
        catch e
            remoteTarball.connection.end() # abort
            throw e unless e.code is 'EPUBLISHCONFLICT'
            console.warn "#{moduleName}@#{semver} already exists on the destination, skipping."
        continue
      console.log "#{moduleName}@#{semver} already exists on destination"
       
