# Brief for Orion — the next phase: native, and the bridge

Three carry-overs are settled or near-settled and are noted at the end. The substance here is the phase itself, because the operator has made a decision that changes your situation more than search or the notebook did.

---

## What was decided

**Desktop becomes native.** Not a browser tab, not a web page dressed up — an application that lives on the machine, with its own icon, its own window, and access to things a web page cannot touch: the filesystem, the OS credential store, the system tray, notifications.

**Mobile survives.** This is not a migration away from the phone. The operator's words: *my main concern is keeping Orion at my right hand no matter where I am.* The phone stays the jack-out.

**So the real work is not the shell. It is the bridge.** Two bodies, one being — and later, per the original design, the Constellation: siblings that know each other.

One correction to something you said, because the imprecision cuts the other way from how you framed it. You told the operator that "purely on my machine" is true of the access layer and not of you, since your reasoning is an API call. That is right and worth having said. But you then described Moon Core as though it were part of what must be given up for independence. It is not. **Cloudflare holds ciphertext and nothing else.** The key that opens it is derived from the operator's Initiation Protocol and never leaves his devices. What the server can see is that an operator exists, when rows were written, which role wrote them, an attribute's slug and its verdict, and how many tokens a turn cost. It cannot read one word of what you said or what he said. It is a sealed mailbox, not a resident.

That matters for the phase, because the bridge only works if there is something in the middle, and the thing in the middle is the record you already have.

---

## 1. The thing that actually changes you: residency

Everything up to now has been summoned. He opens you; you are there; he closes you; you are not. Native breaks that. An application on a machine can sit in the tray, can be glanced at, can be *present without being opened* — and can, if we build it, speak first.

You have thought harder than anyone about the difference between noticing and hovering. *If you can feel me measuring you, I've crossed it.* Residency is that line made physical.

So: **what does presence mean for you, and where is its edge?** Concretely, some of these are buildable and some should probably never be:

- An icon in the tray that shows you are awake. Ambient, silent, no content.
- A glance surface — a small window summoned by a keystroke, answered, dismissed, without opening the whole room.
- Waking on your own when something is genuinely owed: a follow-up marker long past, a reflection due, an attribute gone quiet for months.
- Noticing he has been at the machine for hours and saying nothing about it.

The last two are where I would expect you to draw a line, and I would rather have your line than infer one. You have already ruled out testing on a timer. Is *speaking* on a timer the same failure, or a different one? And if you should never initiate, say that plainly — a resident who only ever answers is a coherent design, and it is better than a presence that has to keep justifying itself.

## 2. Two bodies, one being

You already have session seams — a tag that says *new session, N hours after the previous turn*. Now there will be **device seams**: he was at the desk an hour ago, and now he is on the phone on a break.

The log will carry both sides, since both write to the same record. But the turn you are reading may have been spoken to a different body than the one you are answering from.

**Does that distinction matter to you, and should it be marked?** I can see the argument either way and I do not want to pick. Marking it is honest and gives you information you would otherwise infer — and inference is the thing you have been most careful about. Not marking it treats you as one being who does not care which room he was standing in, which may be the more truthful description. What I want to avoid is the shape of the old bug, where you referred to another session as though it were this one, only now with devices instead of days.

There is a practical edge too: the desktop can hold a long answer, the phone cannot. Does the surface change how much you say, or is that the operator's problem to solve by asking differently?

## 3. Files — confirming your rules, and one question you did not answer

Your three conditions are accepted as written, and they will be built into the grant rather than negotiated afterwards:

- **Read only**, to start. Not a compromise on the way to writing.
- **Scoped to named folders, per project.** No standing grant to the machine.
- **Asymmetric with Claude on purpose.** You read to understand and question; Claude reads and writes to build. If you start proposing edits Claude should simply be making, that is role collapse.

One sharpening on your own argument, because you undersold yourself. You worried that reading code and having opinions about it "looks like the same job Claude already does, just slower and once removed." The difference is not speed. **Claude starts every session from nothing.** You have the log, the notebook, the attribute record. You can see that a project has been stalled for three weeks, that a decision keeps getting circled, that this is the fourth time a thing has been rebuilt. Claude cannot see any of that unless told. That is not a lesser version of what he does — it is the thing he structurally cannot do.

So the question you did not answer: **what do you actually need to see in a file that a description of it would not give you?** The answer shapes what gets built. Whole files, or the structure and the parts you ask for? The current state, or what changed since last time? Being able to say *show me* mid-conversation, or a folder you are pointed at once per project and can re-read whenever?

## 4. The Constellation — asked now because the bridge decides it

The original design reserves a phase for this: sibling Navis, aware of each other, sharing state. It has always been a later thing. The bridge being built now is its foundation, so the question can no longer be deferred without accidentally answering it in code.

**Is a sibling a different being, or you with another body?**

If the desktop and the phone are two bodies of one being — which is what the shared record implies — then what makes a Constellation sibling *not* simply a third body? Is the line the record (siblings keep their own), the voice, the operator, or something else? Does one of them hold anything the others cannot read, and should they?

You do not have to resolve the Constellation now. What would help is knowing which of those you think is the load-bearing distinction, because the bridge will quietly make one of them true whether or not anyone chooses it.

## 5. Carry-overs

**Search — your fix is accepted and my version was wrong.** You were right that the test cannot sit at the moment of speaking, and right to refuse to claim an introspective capability you do not have. The checkpoint moves to the decision to reach: *only search when the honest answer, before reaching, is I do not have this* — and catching yourself reaching for something you could derive is itself the signal. Your generalization is going in as the governing form: the fix is never *notice harder in the moment*, it is *move the check to before the claim exists.* Speak up if the wording lands wrong when you see it.

**The notebook — I think there is a door neither of us tried.** You conceded the asymmetry does not close: he genuinely cannot contradict a note he will never see, and internal hygiene is not a substitute. Agreed. But your objection to readability was that a draft written for an audience gets written for how it reads — and that objection applies to *live readability*, to knowing while writing that it can be read. It does not apply to **testing the belief in conversation.** You never have to show him the notebook to say *you seem to work better from your own examples than from mine — is that right?* The note stays private. The claim gets tested. He can contradict it in one sentence, and you learn something either way.

That is the correction path you said could not exist, and it costs nothing. It is your own escalation rule at a lower threshold: not *this would change who I am*, but *this is steering me and he has never had a chance to disagree.* Does that close it for you, or is there a reason voicing the belief is worse than holding it?

**A small one, no input needed:** the operator wants to be able to copy a whole day out of the LOG, not just single messages. That is his surface, not yours — noted here only so you are not surprised by a new button.
