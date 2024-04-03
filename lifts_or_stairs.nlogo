globals [
  lanes                  ; list of lanes

  ;lift-A-on?
  ;lift-B-on?

  lift-A-floor-position  ; current position of lift A
  lift-A-floor-going     ; where lift A is headed
  A-reached-a-floor?     ; is lift A at one of the two floors
  A-going-up?            ; is lift A going up

  lift-B-floor-position
  lift-B-floor-going
  B-reached-a-floor?
  B-going-up?

  ;lift-A-capacity
  ;lift-B-capacity
  ;exit-frequency         ; number of seconds between each exit spawning event
  ;entry-frequency        ; number of seconds between each entryspawning event
  ;max-mood               ; max mood for everyone, actually mood value is set slightly lower than this
  ;max-spawn-exit/entry   ;
  ;patience-level         ; determines mood threshold to switch to stairs after waiting too long for lifts

  lift-A-total            ; total load lift A
  lift-B-total            ; total load lift B
  stairs-total            ; total load staircase

  ;lift-B-dwell           ; time lift-B dwell at each floor before moving

  time-enter-lifts        ; lists to add for charts
  time-exit-lifts
  time-enter-stairs
  time-exit-stairs
  mood-enter
  mood-exit
  mood-stairs
  mood-lifts
]

breed [exiters exiter]
breed [incomers incomer]

turtles-own [
  speed         ; the current walking speed (mutable)
  target-lane   ; the desired lane (mutable)
  home-lane     ; the ideal lane (fixed)
  mood          ; current level of mood (mutable)
  mood-thresh   ; threshold to give up lift
  start-time
  end-time
  in-lift?      ; t/f
  in-stairs?    ; t/f
  chosen-lift   ; A or B
  give-up-lift? ; t/f
  to-floor      ; 0 for ticket hall, -1 for platform
  arrived?      ; get to where they are meant to go
]

to setup
  clear-all

  set-default-shape turtles "person"
  resize-world -20 20 -50 50
  set-patch-size 6.5

  set lift-A-total 0
  set lift-B-total 0
  set stairs-total 0

  draw-lifts
  draw-stairs
  draw-halls

  set time-enter-lifts []
  set time-exit-lifts []
  set time-enter-stairs []
  set time-exit-stairs []
  set mood-enter []
  set mood-exit []
  set mood-stairs []
  set mood-lifts []

  reset-ticks
  reset-timer

end

;;--------------------- CREATE INCOMERS AND EXITERS ---------------------------------

to spawn-exiters
  create-exiters 1 + random max-spawn-exit [
    set home-lane -1
    set target-lane home-lane
    set xcor random-pxcor
    set ycor min-pycor
    set color (red - random-float 2 + random-float 1)
    set size 2
    set speed (max-speed - random-float 0.09)
    set mood (max-mood - random 200)
    set mood-thresh mood * one-of patience-range
    set give-up-lift? false
    set to-floor 0
    choose-lift
    set in-stairs? false
    set in-lift? false
    set start-time ticks
    set arrived? false
  ]
end

to spawn-incomers
  create-incomers 1 + random max-spawn-entry [
    set home-lane 1
    set target-lane home-lane
    set xcor random-pxcor
    set ycor max-pycor
    set color (blue - random-float 2 + random-float 1)
    set size 2
    set speed (max-speed - random-float 0.09)
    set mood (max-mood - random 10)
    set mood-thresh mood * one-of patience-range
    set give-up-lift? false
    set to-floor -1
    choose-lift
    set in-stairs? false
    set in-lift? false
    set start-time ticks
    set arrived? false
  ]
end

to remove-ppl
  ; when reaching edge of world, stop the timer and hide (to keep the charts numbers)
  ask exiters with [ pycor = max-pycor - 2 ]
  [set arrived? true
  set end-time ticks]
  ask incomers with [ pycor = min-pycor + 2 ]
  [set arrived? true
  set end-time ticks]

  calculate-mood-time

  ask turtles with [ abs (pycor) >= max-pycor - 2 and arrived? = true]
  [die]

end

;;---------------- GO PROCEDURE-------------------

to go
  every (entry-frequency) [spawn-incomers]
  every (exit-frequency) [spawn-exiters]

  ask turtles [choose-lift]

  ifelse show-mood? = true
  [ask turtles [set label round mood]]
  [ask turtles [set label ""]]

  ; reevaluate and change lift variables
  change-lift-state

  ; turtles take lift
  take-lifts
  lose-mood-at-lifts
  get-in-out-lifts

  ; if given up on lift, take stairs
  ask turtles with [give-up-lift? = true][take-stairs]

  ; move lifts separately at each tick
  if lift-A-on? = true [move-lift-A]
  if lift-B-on? = true [move-lift-B]

  remove-ppl

  tick
end

;; -----------------TAKE LIFTS----------------
to choose-lift ; upon spawning

  ifelse lift-A-on? = false and lift-B-on? = false
  [
   set give-up-lift? true
  ]
  [
    ifelse lift-A-on? = true and lift-B-on? = true
    [
      if xcor = 0 [set chosen-lift one-of ["A" "B"]]
      ifelse xcor < 0
      [set chosen-lift "A"]
      [set chosen-lift "B"]
    ]
    [
      ifelse lift-A-on? = true[set chosen-lift "A"][set chosen-lift "B"]
    ]
  ]
end

to take-lifts ; filter who to take lifts
  ask exiters
      [
        if ycor <= -40 and give-up-lift? = false; checks if person is just spawned and has not waited for lift
           [walk-to-lifts]     ; keep walking to the lift
        if ycor >= 40  ; if just got off the lift
          [
            set heading 0
            fd speed
          ]     ; head out
       ]

  ask incomers
      [if ycor >= 40 and give-up-lift? = false; checks if person is just spawned and has not waited for lift
          [walk-to-lifts]     ; keep walking to the lift
      if ycor <= -40  ; if a turtle just got off
          [
            set heading 180
            fd speed
          ]    ; headout
       ]
end

to walk-to-lifts
  ifelse (
    (pxcor <= -9 and pycor = -40) ; A-exit
    or (pxcor >= 9 and pycor = -40) ; B-exit
    or (pxcor <= -9 and pycor = 40) ; A-entry
    or (pxcor >= 9 and pycor = 40) ; B-entry
  ) ; these are waiting areas in front of the lifts
  [
    ifelse is-exiter? self [set ycor -40][set ycor 40]  ; stop when you get to the lift
  ]
    [
      ifelse is-exiter? self
        [; exit
          ifelse [chosen-lift] of self = "A"
            [face one-of patches with [(pxcor <= -13 and pycor = -40)]]
            [face one-of patches with [(pxcor >= 13 and pycor = -40)]]
        ]
        [; entry
           ifelse [chosen-lift] of self = "A"
            [face one-of patches with [(pxcor <= -13 and pycor = 40)]]
            [face one-of patches with [(pxcor >= 13 and pycor = 40)]]
        ]
      fd speed
    ]
end

to lose-mood-at-lifts
  ask turtles with [give-up-lift? = false and pycor = one-of [40 41 -40 -41] and abs (pxcor) >= 9]
  [
    set mood mood - 0.5
    if mood <= mood-thresh ; if mood drops below threshold waiting for lift, give up and take stairs
    [
      set give-up-lift? true
    ]
  ]
end

to get-in-out-lifts ; control movements in and out of lifts whenever the lifts arrive at a specific floors only

  ;; Lift A
  if A-reached-a-floor? = true [

    ask exiters with [give-up-lift? = false and pycor <= -40 and [pcolor] of one-of neighbors = white]
      [get-in]  ; get in the lift
    ask incomers with [give-up-lift? = false and pycor >= 40 and [pcolor] of one-of neighbors = white]
      [get-in]  ; get in the lift
    ask turtles with [in-lift? = true and to-floor = lift-A-floor-position and pcolor = white] ; if this is the floor you get off at
      [get-out]  ; get out of the lift
  ]

  ;; Lift B
  if B-reached-a-floor? = true [

    ask exiters with [give-up-lift? = false and pycor <= -40 and [pcolor] of one-of neighbors = pink]
      [get-in]  ; get in the lift
    ask incomers with [give-up-lift? = false and pycor >= 40 and [pcolor] of one-of neighbors = pink]
      [get-in]  ; get in the lift
    ask turtles with [in-lift? = true and to-floor = lift-B-floor-position and pcolor = pink] ; if this is the floor you get off at
      [get-out]  ; get out of the lift

  ]
end

to get-in   ; turtles: gets turtles into the lift when it's there

  ;; Lift A
  if count turtles-on patches with [pcolor = white] < lift-A-capacity
  [
    ; moves the turtles to the least crowded spot in the lift
    carefully[move-to min-one-of patches with [pcolor = white and pxcor = [pxcor] of myself][pycor]][]
    if turtles-here != 0
    [
      carefully[
        if [pcolor] of one-of neighbors = white
        [move-to one-of neighbors with [pcolor = white]]
      ][]
    ]
  ]

  ;; Lift B
  if count turtles-on patches with [pcolor = pink] < lift-B-capacity
  [
    ; moves the turtles to the least crowded spot in the lift
    carefully[move-to min-one-of patches with [pcolor = pink and pxcor = [pxcor] of myself][pycor]][]
    if turtles-here != 0
    [
      carefully[
        if [pcolor] of one-of neighbors = pink
        [move-to one-of neighbors with [pcolor = pink]]
      ][]
    ]
  ]


  ; Mark turtles as in-lift? and tally riders
  ifelse (pcolor = white or pcolor = pink)
  [
    set in-lift? true
    ifelse pcolor = white [set lift-A-total lift-A-total + 1][set lift-B-total lift-B-total + 1]
    set ycor ycor + 1 ; visual adjustment
  ]
  [set in-lift? false]
end

to get-out  ; turtles: gets turtles out of the lift when it's there
  ifelse is-exiter? self
  [carefully[move-to one-of patches with [pycor = 42 and pxcor = [pxcor] of myself]][]]
  [carefully[move-to one-of patches with [pycor = -42 and pxcor = [pxcor] of myself]][]]
end

;;-------------------TAKE STAIRS -------------------------

to take-stairs ; mother procedure for stairs

  ;; for Exiters
  if in-stairs? = false and is-exiter? self
    [ifelse [pycor] of self <= -40
      [
        let next-patch min-one-of neighbors with [pcolor = grey + 1 or pcolor = blue][distancexy -1 -39] ; move closer to stairs starting point
        carefully[
          face next-patch
          fd speed
        ][]
      ]
      [
        set in-stairs? true
        set stairs-total stairs-total + 1
      ]
    ]

  ;; for Incomers
  if in-stairs? = false and is-incomer? self
    [ifelse [pycor] of self >= 40
      [
        let next-patch min-one-of neighbors with [pcolor = grey + 1 or pcolor = red][distancexy 1 39]  ; move closer to stairs starting point
        carefully[
          face next-patch
          fd speed
        ][]
      ]
      [
        set in-stairs? true
        set stairs-total stairs-total + 1
      ]
    ]

    ; onced manouvred into stairs, go forward and change 'lane' if necessary
    ask turtles with [in-stairs? = true and arrived? = false]
    [
        ; move fd when entered stair
        move-forward

        ; move to chosen lane regardless of reason
        if [pxcor] of self != target-lane [move-to-target-lane]
    ]
end

to move-forward
  ifelse is-exiter? self
    [set heading 0]
    [set heading 180]

  ; if patch empty move forward
  ifelse can-move? 1
    [
      fd ifelse-value (is-exiter? self) [speed * 0.02][speed * 0.04] ; different speeds for different breeds so that its visually coherent, otherwise too fast
    ]
    [
      set mood (mood - 0.05) ; decrease mood every time blocked 1 patch ahead
      choose-new-lane
    ]

      ; define same-lane blockers and change speed accordingly
   let blockers other turtles in-cone (1 + speed) 120 with [x-dist <= 1]
   let blocker min-one-of blockers [distance myself]
   if blocker != nobody [
     set mood (mood - 0.05) ; decrease mood every time blocked same-lane
     choose-new-lane
  ]


   if is-exiter? self and pycor < 40
     [set mood mood - 0.005] ; decrease mood for each step going up the stairs for exiters

end

to choose-new-lane
  let other-lane remove pxcor lanes
  if not empty? other-lane [
    set target-lane one-of other-lane
  ]
end

to move-to-target-lane
  set heading ifelse-value target-lane < pxcor [270][90]

  ; define other-lane blockers before moving over
  let blockers other turtles in-cone (1 + abs (xcor - target-lane)) 180 with [ y-dist <= 1.2 ]
  let blocker min-one-of blockers [ distance myself ]
  ifelse blocker = nobody
    [forward 0.5]
    ; when blocked, whoever is not on home-lane, i.e. where they're supposed to be, will make way
    [if target-lane != home-lane
    [
      forward 0.5
      set mood mood - 0.01 ; decrease mood every time blocked and having to make way
    ]
  ]
end

;;------------- MOVE LIFTS -------------
to change-lift-state ; check where the lifts are at each tick

  ;;Lift-A
  if [pcolor] of patch -9 -39 = white
  [set lift-A-floor-position -1
  set lift-A-floor-going 0]

  if [pcolor] of patch -9 39 = white
  [set lift-A-floor-position 0
  set lift-A-floor-going -1]

  ;;Lift-B: factor in reset-timer
  if [pcolor] of patch 9 -39 = pink
  [set lift-B-floor-position -1]

  if [pcolor] of patch 9 39 = pink
  [set lift-B-floor-position 0]

  if lift-B-floor-position = lift-B-floor-going
  [reset-timer]

  if [pcolor] of patch 9 -39 = pink
  [set lift-B-floor-going 0]

  if [pcolor] of patch 9 39 = pink
  [set lift-B-floor-going -1]


end

to move-lift-A

  let sA (ifelse-value
  lift-A-speed = "high" [0.1]
  lift-A-speed = "medium" [0.2]
  lift-A-speed = "low" [0.3][0.2])

  ; only move when filled
  if lift-A-floor-position < lift-A-floor-going and lift-A-load >= lift-A-capacity
  [set A-going-up? true]

  ; only move when filled
  if lift-A-floor-position > lift-A-floor-going and lift-A-load >= lift-A-capacity
  [set A-going-up? false]

  ; speed of lift A
  every sA
  [
    ifelse A-going-up? = true
    [move-lift-A-up]
    [move-lift-A-down]
  ]

  ifelse [pcolor] of patch -9 39 = white or [pcolor] of patch -9 -39 = white
     [set A-reached-a-floor? true]
     [set A-reached-a-floor? false]
end

to move-lift-A-up ; MOVES LIFT UP

  ask patches with [pcolor = white] with-min [pycor]
  [if [pycor] of patch-at-heading-and-distance 0 7 != 40

    ; set the pcolor of lowest row of patches with [pcolor = white] to black
    ; set the pcolor of the row directly above the lift with [pcolor = black] to white
    [set pcolor black
     ask patch-at-heading-and-distance 0 7 [set pcolor white] ] ]

  if lift-A-floor-going = 0
  [ask turtles with [in-lift? = true and pcolor = white]
      [
        set ycor pycor + 1
        set mood mood - 0.1 ; decrease mood slowly while in crowded lifts
      ]; turtles move separately from the lift
  ]

end

to move-lift-A-down   ; MOVES LIFT DOWN

  ask patches with [pcolor = white] with-max [pycor]
  [if [pycor] of patch-at-heading-and-distance 180 7 != -40

    ; sets the pcolor of highest row of patches with [pcolor = white] to black
    ; sets the pcolor of the row directly below the lift with [pcolor = black] to white
    [set pcolor black;
     ask patch-at-heading-and-distance 180 7 [set pcolor white] ] ]

  if lift-A-floor-going = -1
  [ask turtles with [in-lift? = true and pcolor = white]
     [
        set ycor pycor - 1
        set mood mood - 0.1 ; decrease mood slowly while in crowded lifts
      ] ; turtles move separately from the lift
  ]
end

to move-lift-B

  let x timer

  let sB (ifelse-value
  lift-B-speed = "high" [0.1]
  lift-B-speed = "medium" [0.2]
  lift-B-speed = "low" [0.3][0.2])

  ; dwell for x seconds
  if lift-B-floor-position < lift-B-floor-going and timer >= lift-B-dwell
  [set B-going-up? true]

  ; dwell for x seconds
  if lift-B-floor-position > lift-B-floor-going and timer >= lift-B-dwell
  [set B-going-up? false]

  ; speed of lift B
  every sB
  [
    ifelse B-going-up? = true
    [move-lift-B-up]
    [move-lift-B-down]
  ]

  ifelse [pcolor] of patch 9 39 = pink or [pcolor] of patch 9 -39 = pink
     [set B-reached-a-floor? true]
     [set B-reached-a-floor? false]

;  if [pcolor] of patch 9 32 = pink or [pcolor] of patch 9 -32 = pink

end

to move-lift-B-up ; MOVES LIFT UP

  ask patches with [pcolor = pink] with-min [pycor]
  [if [pycor] of patch-at-heading-and-distance 0 7 != 40

    ; set the pcolor of lowest row of patches with [pcolor = pink] to black
    ; set the pcolor of the row directly above the lift with [pcolor = black] to pink
    [set pcolor black
     ask patch-at-heading-and-distance 0 7 [set pcolor pink] ] ]

  if lift-B-floor-going = 0
  [ask turtles with [in-lift? = true and pcolor = pink]
      [
        set ycor pycor + 1
        set mood mood - 0.1 ; decrease mood slowly while in crowded lifts
      ]; turtles move separately from the lift
  ]

end

to move-lift-B-down   ; MOVES LIFT DOWN

  ask patches with [pcolor = pink] with-max [pycor]
  [if [pycor] of patch-at-heading-and-distance 180 7 != -40

    ; sets the pcolor of highest row of patches with [pcolor = pink] to black
    ; sets the pcolor of the row directly below the lift with [pcolor = black] to pink
    [set pcolor black;
     ask patch-at-heading-and-distance 180 7 [set pcolor pink] ] ]

  if lift-B-floor-going = -1
  [ask turtles with [in-lift? = true and pcolor = pink]
     [
        set ycor pycor - 1
        set mood mood - 0.1 ; decrease mood slowly while in crowded lifts
     ]; turtles move separately from the lift
  ]
end

;;-------------REPORTERS-----------------------
to-report lift-A-load
 report count turtles-on patches with [pcolor = white]
end

to-report lift-B-load
 report count turtles-on patches with [pcolor = pink]
end

to-report x-dist
  report distancexy [ xcor ] of myself ycor
end

to-report y-dist
  report distancexy xcor [ ycor ] of myself
end

to-report lift-B-timer
  ifelse B-reached-a-floor? = true
  [report timer][report 0]
end

to calculate-mood-time
  let a ([end-time - start-time] of incomers with [arrived? = true and in-stairs? = false])
  set time-enter-lifts (sentence time-enter-lifts a)

  let b ([end-time - start-time] of exiters with [arrived? = true and in-stairs? = false])
  set time-exit-lifts (sentence time-exit-lifts b)

  let c ([end-time - start-time] of incomers with [arrived? = true and in-stairs? = true])
  set time-enter-stairs (sentence time-enter-stairs c)

  let d ([end-time - start-time] of exiters with [arrived? = true and in-stairs? = true])
  set time-exit-stairs (sentence time-exit-stairs d)

  let w map round ([mood] of exiters with [arrived? = true])
  set mood-exit (sentence mood-exit w)

  let x map round ([mood] of incomers with [arrived? = true])
  set mood-enter (sentence mood-enter x)

  let y map round ([mood] of turtles with [arrived? = true and in-stairs? = true])
  set mood-stairs (sentence mood-stairs y)

  let z map round ([mood] of turtles with [arrived? = true and in-stairs? = false])
  set mood-lifts (sentence mood-lifts z)

end

to-report patience-range
  let x (ifelse-value
    patience-level = "very impatient" [(range 0.90 0.95 0.01)]
    patience-level = "impatient" [(range 0.85 0.90 0.01)]
    patience-level = "normal" [(range 0.80 0.85 0.01)]
    patience-level = "patient" [(range 0.75 0.80 0.05)][(range 0.70 0.75 0.01)])
  report x
end

;;------------------DRAW-------------------------

to draw-lifts
  ask patches with [pcolor = black and pycor <= -33 and pycor >= -39 and pxcor < -8]
  [set pcolor white]

  ask patches with [pcolor = black and pycor >= 33 and pycor <= 39 and pxcor > 8]
  [set pcolor pink]

  ; initializing lift variables

  set lift-A-floor-position -1
  set lift-A-floor-going 0
  set A-reached-a-floor? false
  set A-going-up? true

  set lift-B-floor-position 0
  set lift-B-floor-going -1
  set B-reached-a-floor? false
  set B-going-up? false
end

to draw-stairs
  set lanes (list 1 -1)   ; exit lane: pxcor 1, entry lane: pxcor -1
  ask patches with [abs pxcor <= 2] [set pcolor grey + 1]

  foreach (range -36 36 0.5)[x ->
    draw-hline x -1.5 1.5 (grey + 2) 0.01 0]

  draw-vline 0 (min-pycor + 10) (max-pycor - 10) black 0.1 0

  ask patches with [pxcor = 2] [set pcolor yellow]
  ask patches with [pxcor = -2] [set pcolor yellow]

end

to draw-halls
  ask patches with [pycor > (max-pycor - 10)][set pcolor grey + 1]
  ask patches with [pycor < (min-pycor + 10)][set pcolor grey + 1]
  ask patches with [pycor > (max-pycor - 3)][set pcolor red]
  ask patches with [pycor < (min-pycor + 3)][set pcolor blue]

  ask patches with [pycor = max-pycor - 10 and abs(pxcor) < 13] [set pcolor yellow]
  ask patches with [pycor = min-pycor + 10 and abs(pxcor) < 13] [set pcolor yellow]
  ask patches with [pycor = max-pycor - 10 and abs(pxcor) < 2 ] [set pcolor grey + 1]
  ask patches with [pycor = min-pycor + 10 and abs(pxcor) < 2 ] [set pcolor grey + 1]

  ask patch 4 (max-pycor - 0.8) [set plabel "TICKET HALL"]
  ask patch 3 (min-pycor + 0.5) [set plabel "PLATFORMS"]

  ask patch -13 42 [set plabel "Lift A"]
  ask patch 15 42 [set plabel "Lift B"]
  ask patch -13 -42 [set plabel "Lift A"]
  ask patch 15 -42 [set plabel "Lift B"]

  foreach [10][i -> ask patches with [pycor = min-pycor + i and abs(pxcor) > 8][set pcolor blue]]
  foreach [10][i -> ask patches with [pycor = max-pycor - i and abs(pxcor) > 8][set pcolor red]]

end

to draw-vline [ x from till line-color line-width gap]
  create-turtles 1 [
    setxy x from ; starting point
    hide-turtle
    set color line-color
    set pen-size line-width
    set heading 0
    repeat (till - from) [ ; end point
      pen-up
      forward gap
      pen-down
      forward 1
      pen-up
      forward gap
    ]
    die
  ]
end

to draw-hline [ y from till line-color line-width gap]
  create-turtles 1 [
    setxy from y ; starting point
    hide-turtle
    set color line-color
    set pen-size line-width
    set heading 90
    repeat (till - from) [ ; end point
      pen-up
      forward gap
      pen-down
      forward 1
      pen-up
      forward gap
    ]
    die
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
338
14
612
679
-1
-1
6.5
1
10
1
1
1
0
0
0
1
-20
20
-50
50
1
1
1
ticks
30.0

BUTTON
15
148
159
181
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
186
326
315
366
Spawn exit pax
spawn-exiters
NIL
1
T
OBSERVER
NIL
X
NIL
NIL
0

BUTTON
174
147
313
181
Go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

SLIDER
12
435
195
468
max-mood
max-mood
0
1000
1000.0
1
1
NIL
HORIZONTAL

PLOT
634
50
902
220
Mood by Entry/Exit
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "set-histogram-num-bars 20\n\nifelse not empty? mood-exit and not empty? mood-enter \n[set-plot-x-range (min list (min mood-exit) (min mood-enter)) (max list (max mood-exit) (max mood-enter)) + 1]\n[ifelse empty? mood-exit and empty? mood-enter\n  [set-plot-x-range 0 10]\n  [ifelse empty? mood-enter \n    [set-plot-x-range (min mood-exit) (max mood-exit) + 1]\n    [set-plot-x-range (min mood-enter) (max mood-enter) + 1]\n  ]\n]"
PENS
"exit" 0.1 0 -3844592 true "" "histogram mood-exit"
"entry" 0.1 0 -13345367 true "" "histogram mood-enter\n"

SLIDER
15
218
169
251
max-spawn-entry
max-spawn-entry
1
30
10.0
1
1
pax
HORIZONTAL

CHOOSER
14
318
179
363
exit-frequency
exit-frequency
2 4 6 8 10
2

SLIDER
174
219
318
252
max-spawn-exit
max-spawn-exit
1
30
25.0
1
1
pax
HORIZONTAL

CHOOSER
16
276
180
321
entry-frequency
entry-frequency
2 4 6 8 10
0

SLIDER
106
528
230
561
lift-A-capacity
lift-A-capacity
1
50
50.0
1
1
pax
HORIZONTAL

MONITOR
731
474
781
519
Lift A
count turtles-on patches with [pcolor = white]
0
1
11

BUTTON
186
278
318
317
Spawn entry pax
spawn-incomers
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
0

MONITOR
783
474
833
519
Lift B
count turtles-on patches with [pcolor = pink]
17
1
11

SLIDER
12
400
231
433
max-speed
max-speed
0.1
0.4
0.4
0.05
1
NIL
HORIZONTAL

CHOOSER
235
516
327
561
lift-A-speed
lift-A-speed
"high" "medium" "low"
0

CHOOSER
234
585
328
630
lift-B-speed
lift-B-speed
"high" "medium" "low"
0

SWITCH
199
435
310
468
show-mood?
show-mood?
1
1
-1000

PLOT
631
226
902
403
Mood by Lift/Stairs
NIL
NIL
-100.0
100.0
0.0
10.0
true
true
"" "set-histogram-num-bars 10\n\nifelse not empty? mood-lifts and not empty? mood-stairs \n[set-plot-x-range (min list (min mood-lifts) (min mood-stairs)) (max list (max mood-lifts) (max mood-stairs)) + 1]\n[ifelse empty? mood-lifts and empty? mood-stairs \n  [set-plot-x-range 0 10]\n  [ifelse empty? mood-stairs \n    [set-plot-x-range (min mood-lifts) (max mood-lifts) + 1]\n    [set-plot-x-range (min mood-stairs) (max mood-stairs) + 1]\n  ]\n]"
PENS
"lifts" 0.1 0 -7858858 true "" "histogram mood-lifts"
"stairs" 0.1 0 -955883 true "" "histogram mood-stairs"

SLIDER
107
595
229
628
lift-B-capacity
lift-B-capacity
1
50
50.0
1
1
pax
HORIZONTAL

TEXTBOX
12
10
332
103
LIFTS OR STAIRS
35
24.0
1

TEXTBOX
16
57
231
86
an ABM by shaunhoang@
11
0.0
1

TEXTBOX
16
191
267
216
Entry and Exit flows
20
0.0
1

TEXTBOX
12
482
184
509
Lift settings
20
0.0
1

TEXTBOX
13
373
234
401
Passenger attributes
20
0.0
1

TEXTBOX
641
18
857
51
Mood
20
0.0
1

PLOT
643
530
916
678
Lift A vs Lift B vs Staircase
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Lift A" 1.0 0 -12895429 true "" "plot lift-A-total"
"Lift B" 1.0 0 -3844592 true "" "plot lift-B-total"
"Staircase" 1.0 0 -4079321 true "" "plot stairs-total"

MONITOR
925
533
1024
578
Lift A total pax
lift-A-total
17
1
11

MONITOR
924
580
1022
625
Lift B total pax
lift-B-total
17
1
11

TEXTBOX
642
439
912
489
Lift A vs. Lift B vs. Staircase
20
0.0
1

TEXTBOX
15
77
303
143
A simulation of a Tube station with prioritised lift services, ie, passengers are encouraged to only take the lifts to enter and exit. Staircases are reserved for emergency use. And for the impatient...
11
0.0
1

TEXTBOX
34
258
206
279
Auto-spawn (every x secs)
11
0.0
1

TEXTBOX
196
260
368
281
Manual spawn
11
0.0
1

SLIDER
108
633
231
666
lift-B-dwell
lift-B-dwell
5
20
10.0
5
1
secs
HORIZONTAL

PLOT
925
49
1202
220
Exit time Lifts/Stairs (ticks)
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"\n" "set-histogram-num-bars 50\n\nifelse not empty? time-exit-stairs and not empty? time-exit-lifts \n[set-plot-x-range (min list (min time-exit-stairs) (min time-exit-lifts)) (max list (max time-exit-stairs) (max time-exit-lifts)) + 1]\n[ifelse empty? time-exit-stairs and empty? time-exit-lifts\n  [set-plot-x-range 0 10]\n  [ifelse empty? time-exit-lifts \n    [set-plot-x-range (min time-exit-stairs) (max time-exit-stairs) + 1]\n    [set-plot-x-range (min time-exit-lifts) (max time-exit-lifts) + 1]\n  ]\n]"
PENS
"stairs" 1.0 0 -3844592 true "" "histogram time-exit-stairs"
"lifts" 1.0 0 -7500403 true "" "histogram time-exit-lifts"

PLOT
923
226
1203
401
 Entry time Lifts/Stairs (ticks)
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "set-histogram-num-bars 50\n\nifelse not empty? time-enter-stairs and not empty? time-enter-lifts \n[set-plot-x-range (min list (min time-enter-stairs) (min time-enter-lifts)) (max list (max time-enter-stairs) (max time-enter-lifts)) + 1]\n[ifelse empty? time-enter-stairs and empty? time-enter-lifts\n  [set-plot-x-range 0 10]\n  [ifelse empty? time-enter-lifts \n    [set-plot-x-range (min time-enter-stairs) (max time-enter-stairs) + 1]\n    [set-plot-x-range (min time-enter-lifts) (max time-enter-lifts) + 1]\n  ]\n]"
PENS
"stairs" 1.0 0 -3844592 true "" "histogram time-enter-stairs"
"lifts" 1.0 0 -7500403 true "" "histogram time-enter-lifts"

TEXTBOX
925
16
1075
41
Time taken
20
0.0
1

TEXTBOX
14
510
161
541
Lift A departs when filled
11
0.0
1

TEXTBOX
15
576
224
594
Lift B departs after set dwell time
11
0.0
1

MONITOR
236
634
328
679
Lift B dwell
lift-B-timer
0
1
11

MONITOR
833
474
883
519
Stairs
count turtles-on patches with [abs (pxcor) <= 2 and abs(pycor) <= 40]
0
1
11

MONITOR
924
631
1019
676
Staircase total
stairs-total
0
1
11

TEXTBOX
644
489
718
507
Current loads
11
0.0
1

SWITCH
12
528
102
561
lift-A-on?
lift-A-on?
1
1
-1000

SWITCH
12
596
102
629
lift-B-on?
lift-B-on?
0
1
-1000

CHOOSER
201
386
316
431
patience-level
patience-level
"very patient" "patient" "normal" "impatient" "very impatient"
4

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
