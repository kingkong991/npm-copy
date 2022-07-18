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


  choose_versions = argv.version
  moduleNames = []

  for inputStr in argv._
    try
      parsed = JSON.parse(inputStr)
      Object.assign(versions, parsed)
      moduleNames = moduleNames.concat(Object.keys(parsed))
    catch e
      moduleNames.push(inputStr)

  unless from.url and (from.auth.token or (from.auth.username and from.auth.password)) and
         to.url and (to.auth.token or (to.auth.username and to.auth.password)) and
         moduleNames.length
    console.log 'usage: npm-copy --from <repository url> --from-token <token> --to <repository url> --to-token <token> moduleA [moduleB...]'
    return

  npm = new RegClient()

  for moduleName in moduleNames
    try
      fromVersionsOriginal = npm.sync.get("#{from.url}/#{moduleName}", auth: from.auth, timeout: 3000).versions
    catch e
      console.log "#{moduleName} not found"
      continue
    try
      toVersions = npm.sync.get("#{to.url}/#{moduleName}", auth: to.auth, timeout: 3000).versions
    catch e
      throw e unless e.code is 'E404'
      toVersions = {}

    if versions[moduleName]
      fromVersions = {}
      versions[moduleName].forEach (v) ->
        if fromVersionsOriginal[v]
          fromVersions[v] = fromVersionsOriginal[v]
    else
      fromVersions = fromVersionsOriginal

    versionsToSync = _.pick (fromVersions, choose_version)

    for semver, oldMetadata of fromVersions

      unless semver in versionsToSync
        console.log "#{moduleName}@#{semver} already exists on destination"
        continue

      {dist} = oldMetadata

      # clone the metadata skipping private properties and 'dist'
      newMetadata = {}
      newMetadata[k] = v for k, v of oldMetadata when k[0] isnt '_' and k isnt 'dist'

      remoteTarball = npm.sync.fetch dist.tarball, auth: from.auth

      try
        # delete fields that github looks for and disqualified if it's not github
        delete newMetadata.publishConfig
        delete newMetadata.repository
        newMetadata.repository = {
          type: 'git',
          url: argv["to-git-repo"]
        }
        res = npm.sync.publish "#{to.url}", auth: to.auth, metadata: newMetadata, access: 'restricted', body: remoteTarball
        console.log "#{moduleName}@#{semver} cloned"
      catch e
        remoteTarball.connection.end() # abort
        throw e unless e.code is 'EPUBLISHCONFLICT'
        console.warn "#{moduleName}@#{semver} already exists on the destination, skipping."
