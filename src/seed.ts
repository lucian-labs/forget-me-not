import type { Task } from './types'
import { createTask, getTasks } from './store'

interface SeedTask {
  title: string
  domain: string
  recurring: boolean
  baseCadenceSeconds: number | null
  prompts: string[]
}

const SEED_TASKS: SeedTask[] = [
  { title: 'eyes off the screen', domain: 'health', recurring: true, baseCadenceSeconds: 900, prompts: [] },
  { title: 'waterize', domain: 'health', recurring: true, baseCadenceSeconds: 3600, prompts: [] },
  { title: 'move around', domain: 'health', recurring: true, baseCadenceSeconds: 3200, prompts: ['stretch', 'bend over', 'walk and breathe'] },
  { title: 'communicate', domain: 'work', recurring: true, baseCadenceSeconds: 7200, prompts: ['social post?', 'email an update', 'blog', 'text'] },
  { title: 'put something away', domain: 'home', recurring: true, baseCadenceSeconds: 5400, prompts: ['has it been there for 5 days?', 'have you used it?', 'or move something stagnant'] },
  { title: 'work out', domain: 'health', recurring: true, baseCadenceSeconds: 14400, prompts: ['heart rate > 120', '50 squats', 'back and legs'] },
  { title: 'dishes', domain: 'home', recurring: true, baseCadenceSeconds: 14400, prompts: [] },
  { title: 'brush teeth', domain: 'health', recurring: true, baseCadenceSeconds: 28800, prompts: [] },
  { title: 'laundry', domain: 'home', recurring: true, baseCadenceSeconds: 28800, prompts: [] },
  { title: 'take a walk', domain: 'health', recurring: true, baseCadenceSeconds: 86400, prompts: ['stretch your legs', 'down the street and back', 'riverwalk!'] },
  { title: 'bathrooms', domain: 'home', recurring: true, baseCadenceSeconds: 604800, prompts: [] },
]

export function loadSeedTasks(): number {
  let count = 0
  for (const seed of SEED_TASKS) {
    createTask({
      title: seed.title,
      domain: seed.domain,
      recurring: seed.recurring,
      baseCadenceSeconds: seed.baseCadenceSeconds,
      prompts: seed.prompts,
    })
    count++
  }
  return count
}

export function loadSeedIfEmpty(): boolean {
  if (getTasks().length > 0) return false
  loadSeedTasks()
  return true
}
