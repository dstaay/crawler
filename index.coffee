request = require 'request'
async = require 'async'
url = require 'url'

SITE = process.env.SITE || 'http://www.google.com'
WORKERS = process.env.WORKERS || 40

class Node
  constructor: (@url) ->
    @links = {}

main = (node, cb) ->
  processed = 0
  root = node

  queue = []
  queue.push(node)

  seen = {}
  seen[node.url.pathname] = node

  q = async.queue (currentNode, eCb) ->
    fullUrl = currentNode.url.protocol + '//' + currentNode.url.host + currentNode.url.pathname
    console.log 'Crawling', currentNode.url.pathname

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
          q.push(newNode)
          seen[candidateUrl.pathname] = newNode
        else # already exists, so use that
          newNode = seen[candidateUrl.pathname]
        currentNode.links[candidateUrl.pathname] = newNode

      processed++
      console.log "****** Processed #{processed}, current Queue #{q.length()} *******" if processed % 100 == 0
      return eCb()
  , WORKERS

  q.push(node)

    # display page and found links
  q.drain = () ->
    keys = Object.keys(seen)
    for key in keys
      node = seen[key]
      console.log 'Path', node.url.path
      for link in Object.keys(node.links)
        console.log '--->', link
    return cb()

site = new Node(url.parse(SITE))

main site, (err) ->
  console.log(err) if err
  process.exit()
