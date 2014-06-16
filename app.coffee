app = angular.module 'app', []

random = (a, b) ->
  [a, b] = [0, a] unless b?
  Math.floor(Math.random() * (b - a) + a)

shuffle = (o) ->
    `for(j, x, i = o.length; i; j = Math.floor(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x)`
    o

sample = (array) ->
  array[random(array.length)]

distance = (a, b) ->
  [x_, y_] = [b.x - a.x, b.y - a.y]
  x_ * x_ + y_ * y_

sqrt = (a) ->
  Math.floor(Math.sqrt(a))

min = (array) ->
  [m, ind] = [array[0], 0]
  for elt, index in array
    [m, ind] = [elt, index] if elt < m
    undefined
  [m, ind]

class Car
  constructor: (@speed, @smart, @scope) ->
    @dist_on_route = 0
    @route = -1
    @inGarage = true
    @getDestination()
    @init()

  init: ->
    @getPos()
    @checkGarage()

  getDestination: ->
    @town = random @scope.towns.length
    accessible = @getAccessible()
    @scope.error "Impossible de trouver des chemins assez longs depuis la ville #{@town}" if accessible.length < @scope.parameters.min_path_length
    @dest = sample(accessible)
    @getShortestPath()

  getAccessible: ->
    tmp = @scope.towns[@town].accessible
    return tmp if tmp?
    self = this
    fun = (visited, accessible, town, dist, callbacks) ->
      return if visited.indexOf(town) != -1
      visited.push town
      accessible.push town if dist >= self.scope.parameters.min_path_length
      routes = self.scope.towns[town].routes
      nexts = (self.scope.routes[r].dest for r in routes)
      for a in nexts
        callbacks.push [fun, visited, accessible, a, (dist + 1), callbacks]
        undefined
      undefined
    accessible = []
    callbacks = []
    fun [], accessible, @town, 0, callbacks
    while callback = callbacks.shift()
      callback[0].apply this, callback.slice(1)
    @scope.towns[@town].accessible = accessible

  getShortestPath: ->
    dist = (Infinity for _ in [0...@scope.towns.length])
    previous = (undefined for _ in [0...@scope.towns.length])

    dist[@town] = 0
    towns = [0...@scope.towns.length]

    while towns.length
      tmp = ((if towns.indexOf(i) == -1 then Infinity else dist[i]) for i in [0...@scope.towns.length])
      u = min(tmp)[1]
      towns.splice towns.indexOf(u), 1
      break if dist[u] == Infinity
      routes = @scope.towns[u].routes
      for route in routes
        route = @scope.routes[route]
        alt = dist[u] + (Math.floor(route.distance * (if ((u == @town && @scope.towns[u].info) || @smart) then (route.using + 1) else 1)) + 1) # Calculus of the delay of a used road (Should consider the last +1 of the formula)
        v = route.dest
        if alt < dist[v]
          dist[v] = alt
          previous[v] = u

    @path = []
    u = @dest
    return undefined unless previous[u]?
    while previous[u]?
      @path.unshift u
      u = previous[u]

    @path

  update: ->
    if @inGarage
      @inGarage = false
      routes = @scope.towns[@town].routes
      next = @path.shift()
      @route = (r for r in routes when @scope.routes[r].dest == next)[0]
    route = @scope.routes[@route]
    @dist_on_route += @speed / (route.using + 1)# Calculus of the delay of a used road
    if @dist_on_route > route.distance
      @inGarage = true
      @town = route.dest
      if @town == @dest
        @getDestination()
        @scope.travels++
    @init()

  getPos: ->
    if @inGarage
      town = @scope.towns[@town]
      [@x, @y] = [town.x, town.y]
    else
      route = @scope.routes[@route]
      town = @scope.towns[route.source]
      angle = @scope.getAngle(route)
      [@x, @y] = [town.x + Math.floor(Math.cos(angle) * @dist_on_route), town.y + Math.floor(Math.sin(angle) * @dist_on_route)]

  checkGarage: ->
    if @inGarage
      @getShortestPath() if @scope.towns[@town].info # Get shortest path again if there is info in the town.
      @scope.towns[@town].garage += 1
      @scope.routes[@route].using -= 1 if @route != -1
      @route = -1
      @dist_on_route = 0
    else if @town != -1
      @scope.towns[@town].garage -= 1
      @scope.routes[@route].using += 1
      @town = -1

app.controller 'Ctrl', ['$scope', '$timeout', ($scope, $timeout) ->
  createTown = ->
    {x: random($scope.parameters.width - 30), y: random($scope.parameters.height - 30), info: false, garage: 0, routes: []}

  initTowns = ->
    $scope.towns = []
    for i in [0...$scope.parameters.nb_towns]
      cont = true
      while cont
        newTown = createTown()
        cont = false
        for town in $scope.towns
          cont = true if distance(newTown, town) < ($scope.parameters.min_distance * $scope.parameters.min_distance)
      $scope.towns.push newTown

  resetGarages = ->
    for town in $scope.towns
      town.garage = 0
      undefined

  initRoutes = ->
    $scope.routes = []
    for source, source_ind in $scope.towns
      distances = ({source: source_ind, dest: dest_ind, distance: sqrt(distance(source, dest)), using: 0} for dest, dest_ind in $scope.towns when source_ind != dest_ind)
      distances.sort((a, b) -> a.distance - b.distance)
      distances = distances.slice(0, $scope.parameters.farest_town)
      for i in [0...random($scope.parameters.min_routes, $scope.parameters.max_routes)]
        source.routes.push $scope.routes.length
        $scope.routes.push distances.splice(random(distance.length), 1)[0]
        undefined
      undefined
    undefined

  resetUsing = ->
    for route in $scope.routes
      route.using = 0
      undefined

  initCars = ->
    $scope.cars = (new Car(random($scope.parameters.min_speed, $scope.parameters.max_speed), ($scope.mode == 'smart_gps' && Math.random() < $scope.parameters.smart_ratio), $scope) for i in [0...($scope.routes.length * $scope.parameters.car_ratio)])

  initSim = ->
    $scope.paused = true
    $scope.step = 1
    $scope.travels = 0
    $scope.errors = []

  $scope.init = (reset) ->
    $scope.modes ||= {
      no_info: "No info"
      with_info: "With some info"
      full_info: "Full info"
      smart_gps: "Smart GPS"
    }
    $scope.parameters ||= {
      width: 1400
      height: 500
      nb_towns: 14
      min_distance: 100
      info_chance: 0.3
      min_routes: 3
      max_routes: 9
      farest_town: 10
      min_speed: 30
      max_speed: 60
      sim_slow: 1
      car_ratio: 1
      smart_ratio: 0.5
      min_path_length: 2
      benchmark_steps: 10000
    }
    initSim()
    if reset
      initTowns()
      initRoutes()
    resetGarages()
    resetUsing()
    initCars()
    $scope.changeMode()
    $scope.saves = window.saves
    $scope.dump = null

  $scope.save = ->
    $scope.dump =
      parameters: $scope.parameters
      towns: $scope.towns
      routes: $scope.routes
      benchmarks: $scope.benchmarks

  $scope.load = (save) ->
    $scope.parameters = save.parameters
    $scope.init true
    $scope.towns = save.towns
    $scope.routes = save.routes
    $scope.init false
    $scope.benchmarks = save.benchmarks

  display = (obj, attributes) ->
    $scope.displayObj = {}
    for attr in attributes
      list = attr.split('.')
      tmp = obj
      for a in list
        tmp = obj[a]
        $scope.displayObj[attr] = tmp
        undefined
    undefined

  $scope.initBenchmark = ->
    $scope.benchmarks = null
    $scope.showBenchmark = !$scope.showBenchmark

  $scope.benchmark = ->
    $scope.benchmarks = {}
    for key, name of $scope.modes
      $scope.changeMode key
      $scope.init false
      for _ in [0...$scope.parameters.benchmark_steps]
        $scope.nextStep()
      $scope.benchmarks[key] = [($scope.travels / $scope.step).toFixed(3), 0]
    $scope.init false
    m = min(val[0] for _, val of $scope.benchmarks)[0]
    val[1] = Math.floor(val[0] * 100 / m) for _, val of $scope.benchmarks

  $scope.error = (error) ->
    $scope.errors.push error if $scope.errors.indexOf(error) == -1

  $scope.keys = (obj) ->
    Object.keys obj if obj?

  $scope.displayRoute = (route) ->
    display route, ['source', 'dest', 'distance', 'using']

  $scope.displayTown = (town) ->
    display town, ['x', 'y', 'info', 'garage', 'routes']

  $scope.displayCar = (car) ->
    display car, ['speed', 'x', 'y', 'route', 'town', 'dist_on_route', 'dest', 'path']

  $scope.displayNone = ->
    $scope.displayObj = null

  $scope.displayParam = (param) ->
    parseFloat($scope.parameters[param].toFixed(2))

  $scope.changeInfo = (town) ->
    town.info = !town.info

  $scope.changeMode = (val) ->
    $scope.mode = if val? then val else if $scope.mode? then $scope.mode else 'no_info'
    smart = $scope.mode == 'smart_gps'
    j = 0
    for town, i in $scope.towns
      town.info = switch $scope.mode
        when 'with_info' then (i * $scope.parameters.info_chance > j && j += 1)
        when 'full_info' then true
        else false
    for car in $scope.cars
      car.smart = smart && (Math.random() < $scope.parameters.smart_ratio)
      undefined

  $scope.requireReset = (name) ->
    ['nb_towns', 'min_distance', 'min_routes', 'max_routes', 'farest_town'].indexOf(name) != -1

  $scope.requireInit = (name) ->
    ['min_speed', 'max_speed', 'car_ratio', 'smart_ratio', 'min_path_length'].indexOf(name) != -1

  $scope.changeParam = (sign, name, val) ->
    change = (
      if val < 0.1 then 0.01
      else if val < 0.2 then 0.05
      else if val < 0.8 then 0.1
      else if val < 0.9 then 0.05
      else if val < 1 then 0.01
      else if val < 2 then 0.5
      else if val < 5 then 1
      else if val < 20 then 3
      else if val < 100 then 10
      else if val < 200 then 50
      else if val < 1000 then 100
      else if val < 2000 then 200)
    $scope.parameters[name] += sign * change
    reset = $scope.requireReset(name)
    $scope.init if reset || $scope.requireInit(name)

  $scope.getAngle = (route) ->
    [source, dest] = [$scope.towns[route.source], $scope.towns[route.dest]]
    Math.atan2((dest.y - source.y), (dest.x - source.x))

  $scope.getCarAngle = (route) ->
    $scope.getAngle($scope.routes[route]) + Math.PI / 2 if route? and $scope.routes[route]?

  $scope.nextStep = ->
    for car in $scope.cars
      car.update()
      undefined
    $scope.step++

  $scope.loop = ->
    if !$scope.paused
      $scope.nextStep()
      $timeout (-> $scope.loop()), $scope.parameters.sim_slow

  $scope.play = ->
    $scope.paused = false
    $scope.loop()

  $scope.pause = ->
    $scope.paused = true
]
