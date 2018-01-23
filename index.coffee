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

  queue = []
  queue.push(node)

  seen = {}
  seen[node.url.pathname] = node

  async.until check.bind(null, queue), (uCb) ->

    parellelLimit = Math.min(20, queue.length)

    batch = []
    while batch.length < parellelLimit
      batch.push(queue.pop()) 

    async.each batch, (currentNode, eCb) ->
      fullUrl = currentNode.url.protocol + '//' + currentNode.url.host + currentNode.url.pathname
      console.log 'Crawling', fullUrl

      request fullUrl, (err, res, body) ->
        eCb(err) if err

        links = body.match(/href=".*?"/g) 

        return eCb() unless links

        for link in links
          link = link.slice(6, -1)
          # case of '//'
          if link[0] == '/' && link[1] == '/'
            link = currentNode.url.protocol + link
            candidateUrl = url.parse(link)
          # case of indirect references
          else if link[0] == '/' || link[0] == '.'
            candidateUrl = url.parse(url.resolve(root.url.href, link))
          # standard url
          else
            candidateUrl = url.parse(link)

          # external link, skip
          if candidateUrl.host != root.url.host
            continue

          # create a new node, and push since needed
          if !seen[candidateUrl.pathname]
            newNode = new Node(candidateUrl)
            queue.push(newNode)
            seen[candidateUrl.pathname] = newNode
          else # already exists, so use that
            newNode = seen[candidateUrl.pathname]
          currentNode.links[candidateUrl.pathname] = newNode
        return eCb()
    , uCb
  , (err) ->
    return cb(err) if err

    # display page and found links
    keys = Object.keys(seen)
    for key in keys
      node = seen[key]
      console.log 'Path', node.url.path
      for link in Object.keys(node.links)
        console.log '--->', link
    return cb()

site = new Node(url.parse('http://www.google.com'))

main site, (err) ->
  console.log(err) if err
  process.exit()
