# OpenAI-Compatible Tool Calling for Chat Completions

A slim implementation guide for adding **tool/function calling** to an OpenAI-compatible Chat Completions API.

This guide is written for developers building against an **OpenAI-compatible endpoint** such as Nebius Token Factory. The request/response shape below follows the **Chat Completions** pattern because that is the compatibility layer many third-party providers expose.

---

## 1. What tool calling is

Tool calling is a **multi-step loop**:

1. Your app sends the model a list of tools it is allowed to call.
2. The model either returns normal assistant text or a tool call.
3. Your app executes the tool locally or on your backend.
4. Your app sends the tool result back to the model.
5. The model returns a final answer or asks for another tool.

That loop is the core pattern to implement.

---

## 2. The minimum request shape

In Chat Completions, you send:

- `model`
- `messages`
- `tools`
- optionally `tool_choice`

A minimal example:

```json
{
  "model": "your-model",
  "messages": [
    {
      "role": "system",
      "content": "You are a robot planner. Use tools instead of guessing robot state."
    },
    {
      "role": "user",
      "content": "Pick up the red block and place it on the blue block."
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_scene_state",
        "description": "Return visible objects and locations in the workspace.",
        "parameters": {
          "type": "object",
          "properties": {},
          "required": []
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "pick_object",
        "description": "Pick up an object by ID.",
        "parameters": {
          "type": "object",
          "properties": {
            "object_id": {
              "type": "string",
              "description": "The object identifier returned by get_scene_state."
            }
          },
          "required": ["object_id"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "place_object",
        "description": "Place the held object at a named location.",
        "parameters": {
          "type": "object",
          "properties": {
            "location_id": {
              "type": "string",
              "description": "A valid location identifier such as on_blue_block or bin_left."
            }
          },
          "required": ["location_id"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}
```

---

## 3. What the model returns

When the model decides to use a tool, the assistant message includes `tool_calls` instead of a normal text answer.

Typical shape:

```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": null,
        "tool_calls": [
          {
            "id": "call_123",
            "type": "function",
            "function": {
              "name": "get_scene_state",
              "arguments": "{}"
            }
          }
        ]
      },
      "finish_reason": "tool_calls"
    }
  ]
}
```

Important details:

- `function.arguments` is usually a **JSON string**, so your app must parse it.
- You should treat tool arguments as **untrusted input** and validate them before doing anything real.

---

## 4. The second request: send tool results back

After executing the tool, append:

1. the assistant message containing the tool call
2. a `tool` message containing the result

Example conversation continuation:

```json
[
  {
    "role": "system",
    "content": "You are a robot planner. Use tools instead of guessing robot state."
  },
  {
    "role": "user",
    "content": "Pick up the red block and place it on the blue block."
  },
  {
    "role": "assistant",
    "content": null,
    "tool_calls": [
      {
        "id": "call_123",
        "type": "function",
        "function": {
          "name": "get_scene_state",
          "arguments": "{}"
        }
      }
    ]
  },
  {
    "role": "tool",
    "tool_call_id": "call_123",
    "content": "{\"objects\":[{\"id\":\"red_block\"},{\"id\":\"blue_block\"}],\"locations\":[\"on_blue_block\",\"bin_left\"]}"
  }
]
```

Then call Chat Completions again with the updated `messages` array.

---

## 5. Reliability rules that matter most

If you want the model to make tool calls reliably, these are the biggest levers.

### A. Define tools at the right abstraction level

Bad:

- `set_pwm(channel, value)`
- `spin_motor(id, duration_ms)`

Better:

- `get_scene_state()`
- `pick_object(object_id)`
- `place_object(location_id)`
- `move_home()`

LLMs are better at choosing **semantic actions** than raw hardware actions.

### B. Make schemas narrow

Use:

- enums when possible
- required fields
- explicit types
- small parameter sets

Bad schema:

```json
{
  "type": "object",
  "properties": {
    "command": { "type": "string" }
  }
}
```

Better schema:

```json
{
  "type": "object",
  "properties": {
    "location_id": {
      "type": "string",
      "enum": ["bin_left", "bin_right", "on_blue_block"]
    }
  },
  "required": ["location_id"]
}
```

### C. Tell the model when it must use tools

Your system prompt should be explicit.

Good prompt fragment:

```text
You are a robot planning assistant.
Use tools for world state and robot actions.
Do not invent object IDs, coordinates, or locations.
If required information is missing, call get_scene_state first.
Return a normal user-facing answer only after all required tool calls are complete.
```

### D. Prefer deterministic settings while building

For tool-calling workflows, lower randomness generally improves consistency.

### E. Validate everything

Even with good prompting, you must validate:

- JSON parse success
- required keys
- allowed enum values
- coordinate bounds
- safety constraints

---

## 6. How to force or constrain tool use

In Chat Completions, `tool_choice` controls whether the model may call tools.

Common modes:

- `"none"` — no tool call allowed
- `"auto"` — model chooses message vs tool call
- `"required"` — model must call one or more tools

You can also force a specific function.

Example:

```json
{
  "tool_choice": {
    "type": "function",
    "function": {
      "name": "get_scene_state"
    }
  }
}
```

Use cases:

- `auto` for normal agent-like behavior
- `required` if the request must go through tools
- forced function choice for tightly-controlled internal steps

---

## 7. The best prompt pattern for reliable tool calls

A practical system prompt template:

```text
You are a planning assistant for a robotic arm.

Rules:
1. Use tools for any action that depends on the real world.
2. Never invent object IDs, positions, locations, or completion status.
3. If the scene is unknown, call get_scene_state before planning.
4. Only call tools that are necessary for the user’s request.
5. After receiving tool results, decide the next best action.
6. When the task is complete, answer briefly in plain language.
7. If a tool result indicates failure, explain the failure and do not pretend the task succeeded.
```

This is usually better than a vague instruction like “use tools when helpful.”

---

## 8. A good robot-oriented tool set

For a hackathon demo, keep the tool set small.

Recommended starter set:

- `get_scene_state()`
- `move_home()`
- `pick_object(object_id)`
- `place_object(location_id)`
- `open_gripper()`
- `close_gripper()`

Optional if you need a lower-level escape hatch:

- `move_to_pose(x, y, z, wrist_rotation)`

Avoid starting with raw motor primitives unless your app must expose them.

---

## 9. Example: full loop in pseudo-code

```python
messages = [
    {"role": "system", "content": SYSTEM_PROMPT},
    {"role": "user", "content": user_input},
]

while True:
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        tools=tools,
        tool_choice="auto",
        temperature=0
    )

    msg = response.choices[0].message
    messages.append(msg)

    if not getattr(msg, "tool_calls", None):
        print(msg.content)
        break

    for tool_call in msg.tool_calls:
        name = tool_call.function.name
        args = json.loads(tool_call.function.arguments)

        validated_args = validate(name, args)
        result = execute_tool(name, validated_args)

        messages.append({
            "role": "tool",
            "tool_call_id": tool_call.id,
            "content": json.dumps(result)
        })
```

---

## 10. Example: a robot tool schema that is reliable

```json
[
  {
    "type": "function",
    "function": {
      "name": "get_scene_state",
      "description": "Return all visible objects and valid target locations in the robot workspace.",
      "parameters": {
        "type": "object",
        "properties": {},
        "required": []
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "pick_object",
      "description": "Pick up one visible object by ID. Only use IDs returned by get_scene_state.",
      "parameters": {
        "type": "object",
        "properties": {
          "object_id": {
            "type": "string",
            "description": "The exact object ID returned by get_scene_state."
          }
        },
        "required": ["object_id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "place_object",
      "description": "Place the currently held object at a valid target location. Only use location IDs returned by get_scene_state.",
      "parameters": {
        "type": "object",
        "properties": {
          "location_id": {
            "type": "string",
            "description": "The exact location ID returned by get_scene_state."
          }
        },
        "required": ["location_id"]
      }
    }
  }
]
```

Why this works well:

- The tools are semantically meaningful.
- The descriptions tell the model where valid IDs come from.
- The model is discouraged from inventing values.

---

## 11. What usually makes tool calling unreliable

### Problem: too many overlapping tools
If you define several tools that all sound similar, the model may choose inconsistently.

Fix: merge or rename tools so their purposes are clearly distinct.

### Problem: weak descriptions
If the description is vague, the model cannot infer when to call it.

Fix: describe both:
- what the tool does
- when it should be used

### Problem: free-form arguments
If a function takes a giant blob of arbitrary text, reliability drops.

Fix: use structured parameters.

### Problem: the model guesses state
If you let the model skip perception, it will sometimes invent facts.

Fix: explicitly require state-reading tools before action tools.

### Problem: one-shot prompting only
You may need a loop: perception → action → result → next action.

Fix: implement the full multi-turn tool loop.

---

## 12. Practical prompt snippets you can reuse

### General tool-use policy

```text
Use tools whenever the answer depends on external state, device state, or real-world conditions.
Do not guess missing values.
```

### Robot safety policy

```text
Never claim a robot action succeeded unless a tool result confirms success.
If a tool returns an error, explain the error and stop or choose a safe alternative.
```

### Scene-awareness policy

```text
Before choosing pick_object or place_object, ensure you know the current scene state.
If scene state is missing or stale, call get_scene_state.
```

### Anti-hallucination policy

```text
Only use object IDs and location IDs that appear in tool outputs.
```

---

## 13. When to use `tool_choice = required`

Use `required` when:

- every valid answer must come from a tool
- you are building an internal step in a workflow
- you never want the model to answer directly first

Example:

```json
{
  "tool_choice": "required"
}
```

For robotics, this is often useful for steps like:

- inspect the scene
- query inventory
- query robot status

Then switch back to `auto` for the rest of the loop if needed.

---

## 14. JSON reliability tips

If you want valid arguments more consistently:

1. Keep tool arguments small.
2. Prefer strings, numbers, booleans, and enums.
3. Avoid nested optional objects unless necessary.
4. Put allowed values in the schema or tool description.
5. Give the model a source of truth tool like `get_scene_state()`.
6. Set `temperature` low during development.
7. Log failures and build eval prompts from real mistakes.

---

## 15. A minimal production checklist

Before executing any tool call:

- parse JSON safely
- reject unknown keys if your validator supports that
- check ranges and enums
- check robot safety state
- check idempotency where needed
- log request ID and tool call ID
- return structured tool errors back to the model

Example error tool result:

```json
{
  "success": false,
  "error": "object_id_not_found",
  "message": "red_block was not present in the current scene"
}
```

This gives the model a chance to recover sensibly.

---

## 16. Chat Completions vs Responses

If you are building against a provider that advertises **OpenAI-compatible Chat Completions**, sticking with the Chat Completions tool-calling shape is reasonable.

If you are building directly against OpenAI, the newer **Responses API** is the current recommended interface for new projects, and it also supports function calling and built-in tools.

For your use case, the important idea is that the **tool-calling loop stays the same** even if the exact wire format differs.

---

## 17. What I would do for your robot app

Use a narrow tool set like this first:

- `get_scene_state()`
- `pick_object(object_id)`
- `place_object(location_id)`
- `move_home()`

Prompt the model like this:

```text
You are a robot planning assistant.
Use tools instead of guessing real-world state.
Always call get_scene_state before manipulating objects unless the latest tool output already provides current scene state.
Only use object IDs and location IDs returned by tools.
After the task is complete, summarize what happened briefly.
```

Then add lower-level tools only if you discover a real need.

---

## 18. Official docs worth reading next

- Function calling guide: https://developers.openai.com/api/docs/guides/function-calling/
- Tools guide: https://developers.openai.com/api/docs/guides/tools/
- Chat Completions API reference: https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create/
- Structured Outputs guide: https://developers.openai.com/api/docs/guides/structured-outputs/
- Responses API reference: https://platform.openai.com/docs/api-reference/responses
- Migration guide: https://developers.openai.com/api/docs/guides/migrate-to-responses/

---

## 19. One-line summary

To make tool calls reliable, do three things well:

1. define **small, high-signal tools**
2. write **explicit system rules** about when tools must be used
3. implement a **strict validation and tool-result loop** in your app
