###
# record, user data
###
request = require('browser-request')
cookie = require("cookie-cutter")
url = require("url")
qs = require("querystring")
uuid = require('node-uuid')
VERSION = require("../package.json").version
_ = require("lodash")



class TRM

  constructor: () ->

    @host = "{DOMAIN_NAME}/track"
    @fbPixelId = "";
    @data = {PIXEL_DATA}
    @targetTable = {TARGET_DATA}
    @pmdReturnData = {}
    @KEYS = {
      ID: "pmd.uuid"
      ADGROUP: "pmd.adGroupId"
      PARAM_ADGROUP: "adgroupid"
      TRACKPIXEL: "pmd.trackPixelId"
      EXPIRES: 7
      FOREVER: 9999999999
      AUDIENCETAGID: "pmd-tag-aid"
    }

    return @



  setNGo: (info) ->
    # info: {email: "xxx"}
    @info = info
    @pmdReturnData = _.cloneDeep info
    @flow()



  flow: () ->

    that = @
    @initFacebookPixel()
    @touchFacebookEvent ["track", "PageView"]
    @touchFacebookEvent ["track", "ViewContent"]
    @id = @data.trackPixelId
    triggers = @data.triggers

    _.forEach triggers, (trigger) ->
      switch trigger.triggerType
        when "Element"
          that.setTriggerElementEvent trigger
        when "Page"
          currentUrl = window.location.href
          if currentUrl.indexOf(trigger.emitUrl) is -1 then return
          that.process trigger

    @touchAdMinerEvent()



  initFacebookPixel: () ->

    this.fbPixelId = "{FB_PIXEL_ID}"

    if not this.hasFbPixelId()
      return

    @touchFacebookEvent ["init", "{FB_PIXEL_ID}"]



  touchFacebookEvent: (dataArray) ->
    # https://developers.facebook.com/docs/marketing-api/facebook-pixel/v2.5#standardevents
    if not this.hasFbPixelId()
      return

    fbq.apply null, dataArray



  hasFbPixelId : () ->

    fbPixelId = this.fbPixelId
    if (not fbPixelId) or (fbPixelId is "null")
      return false
    return true



  setTriggerElementEvent: (trigger) ->

    that = @
    triggerElement = trigger.emitElement
    elements = @queryElement triggerElement

    _.forEach elements, (element) ->
      element.addEventListener "click", () ->
        that.process.call that, trigger, that.touchAdMinerEvent



  process: (trigger, callback) ->

    that = @
    elementsObj = trigger.elementsObj

    data = @collectElementsData elementsObj
    data.triggerEventId = trigger.id

    triggerTarget = trigger.triggerTarget
    fbDataArray = @transformData triggerTarget, data

    # If CheckoutFlow, touch CheckoutFlow + emitStep
    if fbDataArray[1] is "CheckoutFlow"
      step = trigger.emitStep
      triggerTarget = triggerTarget + step
      fbDataArray[1] = fbDataArray[1] + step
      # If emitStep is 1, touch InitiateCheckout as well
      if step is 1
        fbDataForInitiateCheckout = ["track", "InitiateCheckout"]
        fbDataForInitiateCheckout.push fbDataArray[2]
        @touchFacebookEvent fbDataForInitiateCheckout

    @touchFacebookEvent fbDataArray

    if _.isFunction callback
      eventData = _.cloneDeep @info
      eventData[triggerTarget] = data
      callback.call that, eventData
      return

    @pmdReturnData[triggerTarget] = data

    # For Tracker targetValues 相容性
    totalPrices = data.totalPrices
    if totalPrices and totalPrices[0]
      totalPrice = totalPrices[0]
      @pmdReturnData.price = totalPrice
      @pmdReturnData.currency = @data.currency



  collectElementsData: (elementsObj) ->

    that = this
    data = {}

    _.forEach elementsObj, (element, key) ->
      e = that.queryElement element
      if _.isArrayLikeObject e
        e = _.map e, (obj) ->
          return obj.innerText
        data[key] = e
        return
      if e
        data[key] = e.innerText

    return data



  transformData: (adMinerTarget, data) ->

    that = @
    fbData = {}
    returnFbDataArray = []
    targetMap = _.find @targetTable, (targetObj, key) ->
      return key is adMinerTarget

    fieldMap = targetMap.fields

    _.forEach data, (value, key) ->
      fbData[fieldMap[key]] = value
      delete fbData["undefined"]

    otherFields = targetMap.otherFields

    if otherFields
      _.forEach otherFields, (field) ->
        if field is "currency" then fbData.currency = that.data.currency

    return [targetMap.facebookEventType, targetMap.facebookTarget, fbData]



  queryElement: (elementWithQueryInfo) ->

    if elementWithQueryInfo.id
      element = document.getElementById elementWithQueryInfo.id
      return [element]
    if elementWithQueryInfo.class
      return document.getElementsByClassName elementWithQueryInfo.class
    if elementWithQueryInfo.name
      return document.getElementsByName elementWithQueryInfo.name
    return document.querySelectorAll elementWithQueryInfo.custom



  touchAdMinerEvent: (data = undefined) ->

    that = @
    @params = @prepareData()
    @params.params = if data then data else @pmdReturnData

    try
      request {
        method: "POST"
        url: @protocol("#{@host}")
        body: JSON.stringify(@params)
      }, (err, res) ->
        if err
          console.log "There was an error."
        # , but at least browser-request loaded and ran!'
        # result = JSON.parse res.body
        return
        
    catch error
      return console.log("send request, error happen")



  protocol: (url) ->

    protocol = if window.location.protocol is "https:" then "https:" else "http:"
    if url.indexOf("http") is 0
      return url.replace(/^http:|^https:/, protocol)
    return protocol + "//" + url



  prepareData: () ->
    # it will get params and get params from data, and update cookie
    param = @initParams()
    return param



  initParams: () ->
    # get uuid from cookie
    param = {}
    uuid = @getTrmUuid()
    #get adgroup ID, from local cookie or url params
    aid = @getAdGroupId()

    # set all param
    param = {
      trackPixelId: @id || 0
      adGroupId: aid || 0
      referer: document.referrer || ""
      id: uuid
      version: VERSION || ""
    }

    # if console
    #   console.log "final collect params --> "
    #   console.log param

    return param



  getAdGroupId: (url) ->
    #get adgroup from url
    url = url || location.search
    url = url.toLowerCase()
    search = qs.parse(url) || null
    qsFromUrl = search[@KEYS.PARAM_ADGROUP] || ""

    if qsFromUrl.length > 0
      @setCookie @KEYS.ADGROUP, qsFromUrl
      return qsFromUrl

    aid = cookie.get(@KEYS.ADGROUP) || null
    return aid



  #get uuid from cookie, or generate a new uid
  getTrmUuid: () ->
    uid = cookie.get(@KEYS.ID)
    # create a uid
    unless uid
      uid = uuid.v4()
      @setCookie(@KEYS.ID, uid, true)
    return uid



  # set cookie and set it is forever or expreis
  # the expires setting is depend on KEYS
  setCookie: (key, data, forever) ->
    newDate = new Date()

    if forever
      newDate.setHours(newDate.getHours() + @KEYS.FOREVER)
    else
      newDate.setDate(newDate.getDate() + @KEYS.EXPIRES)

    cookie.set(key, data, { expires: newDate, path: "/" })
    return @



global = window || module.exports
global.analytics = global.analytics || []
global.analytics = new TRM()
global.analytics.host = "{DOMAIN_NAME}/track"
global.console = global.console || {
  log: (msg) ->
    return msg
}

module.exports = TRM





