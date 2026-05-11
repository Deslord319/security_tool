import { Component, Driver, ON } from '@kit.TestKit'

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export async function safeDelay(driver: Driver, ms: number): Promise<void> {
  try {
    await driver.delayMs(ms)
  } catch (_err) {
  }
}

export async function findByText(driver: Driver, text: string): Promise<Component | null> {
  try {
    return await driver.findComponent(ON.text(text))
  } catch (_err) {
    return null
  }
}

export async function findById(driver: Driver, id: string): Promise<Component | null> {
  try {
    return await driver.findComponent(ON.id(id))
  } catch (_err) {
    return null
  }
}

export async function clickComponent(component: Component | null): Promise<boolean> {
  if (component === null) {
    return false
  }
  try {
    await component.click()
    return true
  } catch (_err) {
    return false
  }
}

export async function clickByText(driver: Driver, text: string): Promise<boolean> {
  return clickComponent(await findByText(driver, text))
}

export async function clickById(driver: Driver, id: string): Promise<boolean> {
  return clickComponent(await findById(driver, id))
}

export async function existsByText(driver: Driver, text: string): Promise<boolean> {
  return await findByText(driver, text) !== null
}

export async function existsById(driver: Driver, id: string): Promise<boolean> {
  return await findById(driver, id) !== null
}
