(($) ->

  $.emberMockJax = (options) ->

    # defaults
    config =
      fixtures: {}
      urls: ["*"]
      debug: false

    settings = $.extend settings, options

    log = (msg) ->
      console?.log msg if settings.debug

    parseUrl = (url) ->
      parser = document.createElement('a')
      parser.href = url
      parser

    findRecords = (fixtures, fixtureName, queryParams, requestData) ->
      fixtures[fixtureName].filter (element, index) ->
        matches = 0
        for param in queryParams
          continue unless requestData[param]?
          if typeof requestData[param] is "object"
            if element[param.singularize()].toString() in requestData[param] or element[param.singularize()] in requestData[param]
              matches += 1
          else if typeof requestData[param] is "boolean"
            if element[param]? == true then bool = true else bool = false
            if requestData[param] == bool
              matches += 1
          else
            matches += 1 if requestData[param] = element[param]
        true if matches == queryParams.length

    uniqueArray = (arr) ->
      arr = arr.map (k) -> k.toString()
      $.grep arr, (v, k) ->
        $.inArray(v ,arr) == k

    sideloadRecords = (fixtures, name, parent) ->
      temp = []
      params = []
      res = []
      parent.forEach (record) ->
        $.merge(res, record[name.singularize() + "_ids"])

      params["ids"] = uniqueArray res
      findRecords(fixtures,name.capitalize(),["ids"],params)

    addRelatedRecord = (fixtures, json, name, new_record, singleResourceName) ->
      json[name.resourceize()] = [] unless typeof json[name.resourceize()] is "object"
      duplicated_record = $.extend(true, {}, fixtures[name.fixtureize()].slice(-1).pop())
      duplicated_record.id = parseInt(duplicated_record.id) + 1
      $.extend(duplicated_record,new_record[singleResourceName][name + "_attributes"])
      fixtures[name.fixtureize()].push(duplicated_record)
      delete new_record[singleResourceName][name + "_attributes"]
      new_record[singleResourceName][name + "_id"] = duplicated_record.id
      json[name.resourceize()].push(duplicated_record)
      json

    addRecord = (fixtures, json, new_record, fixtureName, resourceName, singleResourceName) ->
      duplicated_record = $.extend(true, {}, fixtures[fixtureName].slice(-1).pop())
      duplicated_record.id = parseInt(duplicated_record.id) + 1
      $.extend(duplicated_record, new_record[singleResourceName])
      fixtures[fixtureName].push(duplicated_record)
      json[resourceName].push(duplicated_record)
      json

    String::fixtureize = ->
      this.camelize().capitalize().pluralize() if typeof name is "string"

    String::resourceize = ->
      this.pluralize().underscore() if typeof name is "string"

    $.mockjax
      url: "*"
      responseTime: 0
      response: (request) ->

        queryParams             = []
        json                    = {}

        requestType             = request.type.toLowerCase()
        pathObject              = parseUrl(request.url)["pathname"].split("/")
        modelName               = pathObject.slice(-1).pop()
        putId                   = null

        if /^[0-9]+$/.test modelName
          if requestType is "get"
            request.data = {} if typeof request.data is "undefined"
            request.data.ids = [modelName]

          if requestType is "put"
            putId = modelName

          modelName = pathObject.slice(-2).shift().singularize().camelize().capitalize()

        else
          modelName = modelName.singularize().camelize().capitalize()

        fixtureName             = modelName.fixtureize()
        resourceName            = modelName.resourceize()
        singleResourceName      = resourceName.singularize()
        emberRelationships      = Ember.get(App[modelName], "relationshipsByName")
        fixtures                = settings.fixtures
        queryParams             = Object.keys(request.data) if typeof request.data is "object"
        modelAttributes         = Object.keys(App[modelName].prototype).filter (e) ->
                                    true unless e is "constructor" or e in emberRelationships.keys.list

        if requestType is "post"
          new_record = JSON.parse(request.data)
          json[resourceName] = []
          emberRelationships.forEach (name,relationship) ->
            if "nested" in Object.keys(relationship.options)
              unless relationship.options.async
                json = addRelatedRecord(fixtures,json,name,new_record,singleResourceName)

          @responseText = addRecord(fixtures,json,new_record,fixtureName,resourceName,singleResourceName)

        if requestType is "put"
          new_record = JSON.parse(request.data)
          json[resourceName] = []
          emberRelationships.forEach (name,relationship) ->
            if "nested" in Object.keys(relationship.options)
              unless relationship.options.async
                fixtures[name.fixtureize()].forEach (record) ->
                  if record.id is parseInt(new_record[singleResourceName][name + "_attributes"].id)
                    $.extend(record, new_record[singleResourceName][name + "_attributes"])
                    json[name.resourceize()] = [] if typeof json[name.resourceize()] is "undefined"
                    json[name.resourceize()].push(record)
                delete new_record[singleResourceName][name + "_attributes"]

          fixtures[fixtureName].forEach (record) ->
            if record.id is parseInt(putId)
              json[resourceName] = [] if typeof json[resourceName] is "undefined"
              $.extend(record, new_record[singleResourceName])
              json[resourceName].push(record)

          @responseText = json

        if requestType is "get"
          console.warn("Fixtures not found for Model : #{modelName}") unless fixtures[fixtureName]
          if queryParams.length
            json[resourceName] = findRecords(fixtures,fixtureName,queryParams,request.data)
          else
            json[resourceName] = fixtures[fixtureName]

          emberRelationships.forEach (name,relationship) ->
            # async = false / sideload records
            if "async" in Object.keys(relationship.options)
              unless relationship.options.async
                json[name] = sideloadRecords(fixtures,name,json[resourceName])

          @responseText = json

        console.log "MOCKJAX RESPONSE:", @responseText
) jQuery