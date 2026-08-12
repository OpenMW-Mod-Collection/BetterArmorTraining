local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local I = require('openmw.interfaces')
local ui = require('openmw.ui')
local async = require('openmw.async')
local util = require('openmw.util')

local function capitalizeText(text)
   local capitalizedText = ""
   local i = 1
   capitalizedText = text:sub(i, i):upper()
   i = i + 1
   while i <= #text do
      local j = text:find(" ", i)
      if j ~= nil then
         capitalizedText = capitalizedText .. text:sub(i, j) .. text:sub(j + 1, j + 1):upper()
         i = j + 2
      else
         break
      end
   end
   capitalizedText = capitalizedText .. text:sub(i, #text)
   return capitalizedText
end










I.Settings.registerRenderer('textset', function(input, set, args)
   if args == nil then args = {} end
   if input == nil then
      input = {}
      set(input)
   end

   local removeText = 'x'
   if args.removeText ~= nil and args.removeText ~= "" then
      removeText = args.removeText
   end

   local header = {
      type = ui.TYPE.Flex,
      props = {
         horizontal = true,
      },
      content = ui.content({}),
      external = {
         stretch = 1,
      },
   }

   local inputText = ''

   header.content:add({
      template = I.MWUI.templates.box,
      content = ui.content({ {
         template = I.MWUI.templates.padding,
         content = ui.content({ {
            template = I.MWUI.templates.textNormal,
            props = {
               text = "Add",
            },
            events = {
               mouseClick = async:callback(function()

                  if inputText == "" then return end
                  if input[inputText] ~= nil then return end
                  if args.keys ~= nil and #args.keys >= 1 then
                     local i = 1
                     while i <= #args.keys do
                        if args.keys[i] == inputText then break end
                        i = i + 1
                     end
                     if i > #args.keys then return end
                  end
                  if args.lowercase ~= nil and args.lowercase == true then inputText = inputText:lower() end
                  input[inputText] = true
                  set(input)
               end),
            },
         }, }),
      }, }),
   })

   header.content:add({
      template = I.MWUI.templates.padding,
      external = {
         grow = 1,
      },
   })

   header.content:add({
      template = I.MWUI.templates.box,
      content = ui.content({ {
         template = I.MWUI.templates.padding,
         content = ui.content({ {
            template = I.MWUI.templates.textEditLine,
            events = {
               textChanged = async:callback(function(text)
                  inputText = text
               end),
            },
         }, }),
      }, }),
   })

   local body = {
      type = ui.TYPE.Flex,
      content = ui.content({}),
   }

   local function remove(text)
      input[text] = nil
   end

   local buttonWidth = 80
   if args.buttonWidth ~= nil and args.buttonWidth > -1 then
      buttonWidth = args.buttonWidth
   end
   for text in pairs(input) do
      local display = text
      local alpha = 0.5
      if args.pretty == true then display = capitalizeText(text) end
      if input[text] == true then alpha = 1.0 end

      body.content:add({
         template = I.MWUI.templates.padding,
      })

      body.content:add({
         template = I.MWUI.templates.box,
         content = ui.content({ {
            template = I.MWUI.templates.padding,
            content = ui.content({ {
               type = ui.TYPE.Flex,
               props = {
                  horizontal = true,
                  arrange = ui.ALIGNMENT.Center,
               },
               content = ui.content({
                  {
                     template = I.MWUI.templates.padding,
                     events = {
                        mouseClick = async:callback(function()
                           remove(text)
                           set(input)
                        end),
                     },
                     content = ui.content({ {
                        template = I.MWUI.templates.textNormal,
                        props = {
                           text = removeText,
                        },
                     }, }),
                  },
                  {
                     template = I.MWUI.templates.padding,
                     content = ui.content({ {
                        template = I.MWUI.templates.textNormal,
                        props = {
                           text = '|',
                        },
                     }, }),
                  },
                  {
                     template = I.MWUI.templates.padding,
                     events = {
                        mouseClick = async:callback(function()
                           input[text] = input[text] == false
                           set(input)
                        end),
                     },
                     content = ui.content({
                        {
                           template = I.MWUI.templates.textNormal,
                           props = {
                              text = display,
                              alpha = alpha,
                           },
                        },
                        {
                           template = I.MWUI.templates.interval,
                           props = {
                              position = util.vector2(buttonWidth, 0),
                           },
                        },
                     }),
                  },
               }),
            }, }),
         }, }),
      })
   end

   return {
      type = ui.TYPE.Flex,
      content = ui.content({
         header,
         body,
      }),
   }
end)





















I.Settings.registerRenderer('multiselect', function(input, set, args)
   local buttonWidth = 80
   if input == nil then input = {} end
   if args == nil then args = {} end
   if args.keys ~= nil then
      for _, text in ipairs(args.keys) do
         input[text] = input[text] or false
      end
   end
   if args.buttonWidth ~= nil and args.buttonWidth > -1 then
      buttonWidth = args.buttonWidth
   end
   local state = args.buttonStates or {}

   local body = {
      type = ui.TYPE.Flex,
      props = {
         horizontal = false,
         arrange = ui.ALIGNMENT.Start,
      },
      content = ui.content({}),
   }

   for _, key in ipairs(args.keys) do
      local buttonLabel = state.disabled or {}
      local label = key

      if args.aliases ~= nil and args.aliases[key] ~= nil then label = args.aliases[key] end
      if buttonLabel.alpha == nil then
         buttonLabel.alpha = 0.5
      end
      if input[key] == true then
         buttonLabel = state.enabled or {}
         if buttonLabel.alpha == nil then buttonLabel.alpha = 1.0 end
      end

      local buttonText = ui.create({
         template = I.MWUI.templates.textNormal,
         props = {
            text = label,
         },
      }, {})

      buttonText.layout.props.alpha = buttonLabel.alpha
      buttonText.layout.props.textColor = buttonLabel.color or buttonText.layout.props.textColor

      body.content:add({
         template = I.MWUI.templates.padding,
      })

      body.content:add({
         type = ui.TYPE.Flex,
         props = {
            horizontal = true,
         },
         content = ui.content({ {
            template = I.MWUI.templates.box,
            content = ui.content({ {
               template = I.MWUI.templates.padding,
               content = ui.content({ {
                  template = I.MWUI.templates.padding,
                  content = ui.content({
                     buttonText,
                     {
                        template = I.MWUI.templates.interval,
                        props = {
                           position = util.vector2(buttonWidth, 0),
                        },
                     },
                  }),
               }, }),
            }, }),
         }, }),
         events = {
            mouseClick = async:callback(function()
               input[key] = input[key] == false
               set(input)
            end),
         },
      })
   end

   return {
      type = ui.TYPE.Flex,
      content = ui.content({
         body,
      }),
   }
end)









I.Settings.registerRenderer('multinumber', function(input, set, args)
   local lastInput = {}
   if args == nil then args = {} end
   if args.keys ~= nil then
      for _, k in ipairs(args.keys) do
         if input[k] == nil then
            input[k] = 0
         end
      end
   end

   local body = {
      type = ui.TYPE.Flex,
      props = {
         horizontal = false,
         arrange = ui.ALIGNMENT.End,
      },
      content = ui.content({}),
   }

   for _, key in ipairs(args.keys) do
      local label = key
      if args.aliases ~= nil and args.aliases[key] ~= nil then label = args.aliases[key] end

      body.content:add({
         template = I.MWUI.templates.padding,
      })
      body.content:add({
         type = ui.TYPE.Flex,
         props = {
            horizontal = true,
            arrange = ui.ALIGNMENT.Center,
         },
         content = ui.content({
            {
               template = I.MWUI.templates.padding,
               content = ui.content({ {
                  template = I.MWUI.templates.textNormal,
                  props = {
                     text = label,
                     textAlignV = ui.ALIGNMENT.Center,
                  },
               }, }),
            },
            {
               template = I.MWUI.templates.padding,
            },
            {
               template = I.MWUI.templates.box,
               content = ui.content({ {
                  template = I.MWUI.templates.padding,
                  content = ui.content({ {
                     template = I.MWUI.templates.textEditLine,
                     props = {
                        text = tostring(input[key]),
                        size = util.vector2(80, 0),
                     },
                     events = {
                        textChanged = async:callback(function(text)
                           lastInput[key] = tonumber(text)
                        end),
                        focusLoss = async:callback(function()
                           local num = lastInput[key]
                           if num == nil then
                              return
                           end
                           if args.integer == true then
                              num = math.floor(num + 0.5)
                           end
                           if args.min ~= nil and args.min[key] ~= nil and num < args.min[key] then
                              num = args.min[key]
                           elseif args.max ~= nil and args.max[key] ~= nil and num > args.max[key] then
                              num = args.max[key]
                           end
                           input[key] = num
                           set(input)
                        end),
                     },
                  }, }),
               }, }),
            },
         }),
      })
   end

   return {
      type = ui.TYPE.Flex,
      content = ui.content({
         body,
      }),
   }
end)
