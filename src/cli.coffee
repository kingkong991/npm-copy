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

  choose_version = argv.version
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
    
# sync choose_version to npm repo  
    if choose_version
      fromVersions = _.pick(fromVersions, choose_version)
      toVersions = _.pick(toVersions, choose_version)
    end
    
    for version in Object.keys(fromVersions)
      if toVersions[version]
        console.log "#{moduleName}@#{version} already exists in #{to.url}"
        continue
      end
      console.log "copying #{moduleName}@#{version} to #{to.url}"
      npm.sync.put("#{to.url}/#{moduleName}/#{version}", body: fromVersions[version], auth: to.auth, timeout: 3000)
    end
  end
end

  
