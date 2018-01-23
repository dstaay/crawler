request = require 'request'
async = require 'async'
url = require 'url'


class Node
  constructor: (@url) ->
    @links = {}

check = (queue) ->
  console.log 'Current Queue Length', queue.length
  return (queue.length == 0)

main = (node, cb) ->
  root = node
  node.url.target = node.url.hostname.concat(node.url.pathname)

  queue = []
  queue.push(node)

  seen = {}
  seen[node.url.target] = node

  async.until check.bind(null, queue), (uCb) ->

    parellelLimit = Math.min(20, queue.length)

    batch = []
    while batch.length < parellelLimit
      batch.push(queue.pop()) 

    async.each batch, (currentNode, eCb) ->
      fullUrl = currentNode.url.protocol + '//' + currentNode.url.target
      console.log 'Crawling', fullUrl

      request fullUrl, (err, res, body) ->
        eCb(err) if err

        links = body.match(/href=".*?"/g) 

        return eCb() unless links

        for link in links
          link = link.slice(6, -1)
          candidateUrl = url.parse(link)

          # external link, skip
          if candidateUrl.host != root.url.host
            continue

          # indirect reference
          if !candidateUrl.host
            candidateUrl.host = root.url.host

          candidateUrl.target = candidateUrl.host.concat(candidateUrl.pathname)

          # create a new node, and push since needed
          if !seen[candidateUrl.target]
            newNode = new Node(candidateUrl)
            queue.push(newNode)
            seen[candidateUrl.target] = newNode
          else # already exists, so use that
            newNode = seen[candidateUrl.target]
          currentNode.links[candidateUrl.target] = newNode
        return eCb()
    , uCb
  , (err) ->
    return cb(err) if err

    # display page and found links
    keys = Object.keys(seen)
    for key in keys
      node = seen[key]
      console.log 'Page', node.url.target
      for link in Object.keys(node.links)
        console.log '--->', link
    return cb()

site = new Node(url.parse('http://www.google.com'))

main site, (err) ->
  console.log(err) if err
  process.exit()
