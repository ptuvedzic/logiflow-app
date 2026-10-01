import { z } from "zod";

export const EXPENSE_CATEGORIES = [
  "fuel",
  "toll",
  "driver",
  "maintenance",
  "other",
] as const;

export const EXPENSE_CATEGORY_LABELS = {
  fuel: "Fuel",
  toll: "Toll",
  driver: "Driver",
  maintenance: "Maintenance",
  other: "Other",
} as const satisfies Record<(typeof EXPENSE_CATEGORIES)[number], string>;

const amountSchema = z
  .string({ error: "Enter an amount." })
  .trim()
  .regex(
    /^(?:0*[0-9]{1,10})(?:\.[0-9]{1,2})?$/,
    "Enter a positive amount with up to ten whole digits and two decimal places.",
  )
  .transform(Number)
  .pipe(z.number().positive("Amount must be greater than zero.").max(9_999_999_999.99));

const expenseFields = z.object({
  category: z.enum(EXPENSE_CATEGORIES, { error: "Select an expense category." }),
  amount: amountSchema,
  expenseDate: z
    .string({ error: "Enter an expense date." })
    .trim()
    .refine((value) => z.iso.date().safeParse(value).success, "Enter a valid expense date."),
  description: z
    .string()
    .trim()
    .transform((value) => (value === "" ? null : value)),
});

export const expenseCreateSchema = z.object({
  shipmentId: z.uuid({ error: "Shipment unavailable." }),
}).and(expenseFields);

export const expenseEditSchema = z.object({
  shipmentId: z.uuid({ error: "Shipment unavailable." }),
  expenseId: z.uuid({ error: "Expense unavailable." }),
  expectedUpdatedAt: z.iso.datetime({ offset: true, error: "Expense unavailable." }),
}).and(expenseFields);

export const shipmentExpenseTargetSchema = z.object({
  shipmentId: z.uuid({ error: "Shipment unavailable." }),
}).strict();

export type ExpenseCategory = (typeof EXPENSE_CATEGORIES)[number];
export type ExpenseCreateInput = Readonly<z.infer<typeof expenseCreateSchema>>;
export type ExpenseEditInput = Readonly<z.infer<typeof expenseEditSchema>>;
