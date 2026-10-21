import CoreFoundation
import CryptoKit
import Foundation

/// The closed, value-only request accepted by the planning write tool.
nonisolated struct PlanningChangeRequest: Sendable {
    let requestID: String
    let workspaceID: String
    let month: SelectedStatementMonth
    let planID: String
    let expectedWriteRevision: String
    let changes: [PlanningChange]

    static func decode(_ data: Data) throws -> Self {
        let raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let object = try PlanningChangeParser.object(raw, allowed: ["request_id", "workspace_id", "month", "plan_id", "expected_write_revision", "changes"], required: ["request_id", "workspace_id", "month", "plan_id", "expected_write_revision", "changes"], at: "$" )
        let requestID = try PlanningChangeParser.uuid(object["request_id"], at: "request_id")
        let workspaceID = try PlanningChangeParser.id(object["workspace_id"], at: "workspace_id")
        let month = try PlanningChangeParser.month(object["month"], at: "month")
        let planID = try PlanningChangeParser.id(object["plan_id"], at: "plan_id")
        let revision = try PlanningChangeParser.string(object["expected_write_revision"], at: "expected_write_revision")
        guard revision.range(of: #"^planning-write-v1:[0-9a-f]{64}$"#, options: .regularExpression) != nil else {
            throw PlanningChangeError.invalid("expected_write_revision")
        }
        guard let rawChanges = object["changes"] as? [Any], (1...32).contains(rawChanges.count) else {
            throw PlanningChangeError.invalid("changes")
        }
        let changes = try rawChanges.enumerated().map { try PlanningChangeParser.change($0.element, at: "changes[\($0.offset)]") }
        try PlanningChangeParser.checkDuplicateAssignments(changes)
        return Self(requestID: requestID, workspaceID: workspaceID, month: month, planID: planID,
                    expectedWriteRevision: revision, changes: changes)
    }

    /// Sorted object keys and canonical Money/date spellings form the durable retry digest.
    func canonicalData() throws -> Data {
        let value: [String: Any] = [
            "request_id": requestID, "workspace_id": workspaceID, "month": month.canonical,
            "plan_id": planID, "expected_write_revision": expectedWriteRevision,
            "changes": try changes.map { try $0.jsonObject() }
        ]
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    func digestSHA256() throws -> String {
        SHA256.hash(data: try canonicalData()).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum PlanningChangeError: Error, Equatable, Sendable {
    case invalid(String)
    case unknownKey(String)
    case missing(String)
    case duplicateAssignment(String)
    case conflictingRow(String)
}

/// Omission, explicit JSON null, and a supplied value have different meanings.
nonisolated enum PlanningPatch<Value: Sendable>: Sendable {
    case omitted
    case null
    case value(Value)

    var isSupplied: Bool {
        if case .omitted = self { return false }
        return true
    }
}

nonisolated struct PlanningMoney: Equatable, Sendable {
    let money: Money
    let decimal: String

    var currency: String { money.currency.code }
    var jsonObject: [String: Any] { ["currency": currency, "decimal": decimal] }
}

nonisolated enum PlanningMonthlyField: String, Sendable {
    case expectedFixed = "expected_fixed"
    case expectedVariable = "expected_variable"
    case configuredTransferFee = "configured_transfer_fee"
    case keepInCBQ = "keep_in_cbq"
}

nonisolated enum PlanningRegion: String, Sendable { case qatar, india }
nonisolated enum PlanningAllocationAction: String, Sendable { case create, update }
nonisolated enum PlanningAllocationKind: String, Sendable { case contribution, transfer, investment }

nonisolated enum PlanningInstrument: Sendable, Equatable {
    case ibkr(conid: String, title: String, quoteCurrency: String)
    case indianMutualFund(schemeCode: String, title: String)

    var jsonObject: [String: Any] {
        switch self {
        case let .ibkr(conid, title, quoteCurrency):
            return ["kind": "ibkr", "conid": conid, "title": title, "quote_currency": quoteCurrency]
        case let .indianMutualFund(schemeCode, title):
            return ["kind": "indian_mutual_fund", "scheme_code": schemeCode, "title": title]
        }
    }
}

nonisolated struct PlanningObligationFields: Sendable {
    let amount: PlanningPatch<PlanningMoney>
    let dueDate: PlanningPatch<StatementDate>
    let included: PlanningPatch<Bool>
    let payingAccountID: PlanningPatch<String>
}

nonisolated struct PlanningBalanceFields: Sendable {
    let amount: PlanningPatch<PlanningMoney>
    let included: PlanningPatch<Bool>
}

nonisolated struct PlanningContributionFields: Sendable {
    let amount: PlanningPatch<PlanningMoney>
    let date: PlanningPatch<StatementDate>
    let fundingAccountID: PlanningPatch<String>
    let fundingTransferID: PlanningPatch<String>
}

nonisolated struct PlanningTransferFields: Sendable {
    let fromAccountID: PlanningPatch<String>
    let toAccountID: PlanningPatch<String>
    let received: PlanningPatch<PlanningMoney>
    let date: PlanningPatch<StatementDate>
    let fundingTransferID: PlanningPatch<String>
    let requiredIndiaFunding: PlanningPatch<PlanningMoney>
}

nonisolated struct PlanningInvestmentFields: Sendable {
    let instrument: PlanningPatch<PlanningInstrument>
    let fundingAccountID: PlanningPatch<String>
    let amount: PlanningPatch<PlanningMoney>
    let date: PlanningPatch<StatementDate>
    let fundingTransferID: PlanningPatch<String>
}

nonisolated struct PlanningAllocationLinksFields: Sendable {
    let requiredIndiaTransferID: PlanningPatch<String>
    let keepInCBQDesignationID: PlanningPatch<String>
}

nonisolated enum PlanningChange: Sendable {
    case monthlyAmount(field: PlanningMonthlyField, amount: PlanningMoney)
    case deductionAmount(deductionID: String, amount: PlanningMoney)
    case obligation(region: PlanningRegion, obligationID: String, fields: PlanningObligationFields)
    case planningBalance(balanceID: String, accountID: String, fields: PlanningBalanceFields)
    case manualFX(inrPerQAR: Decimal, observationDate: StatementDate)
    case contribution(action: PlanningAllocationAction, designationID: String, fields: PlanningContributionFields)
    case transfer(action: PlanningAllocationAction, transferID: String, fields: PlanningTransferFields)
    case investment(action: PlanningAllocationAction, investmentID: String, fields: PlanningInvestmentFields)
    case allocationLinks(fields: PlanningAllocationLinksFields)
    case removeAllocation(kind: PlanningAllocationKind, recordID: String)

    func jsonObject() throws -> [String: Any] {
        switch self {
        case let .monthlyAmount(field, amount):
            return ["type": "monthly_amount", "field": field.rawValue, "amount": amount.jsonObject]
        case let .deductionAmount(id, amount):
            return ["type": "deduction_amount", "deduction_id": id, "amount": amount.jsonObject]
        case let .obligation(region, id, fields):
            var patch: [String: Any] = [:]
            try Self.put(fields.amount, "amount", into: &patch) { $0.jsonObject }
            try Self.put(fields.dueDate, "due_date", into: &patch) { $0.canonical }
            try Self.put(fields.included, "included", into: &patch) { $0 }
            try Self.put(fields.payingAccountID, "paying_account_id", into: &patch) { $0 }
            return ["type": "obligation", "region": region.rawValue, "obligation_id": id, "fields": patch]
        case let .planningBalance(id, accountID, fields):
            var patch: [String: Any] = [:]
            try Self.put(fields.amount, "amount", into: &patch) { $0.jsonObject }
            try Self.put(fields.included, "included", into: &patch) { $0 }
            return ["type": "planning_balance", "balance_id": id, "account_id": accountID, "fields": patch]
        case let .manualFX(rate, date):
            return ["type": "manual_fx", "inr_per_qar": NSDecimalNumber(decimal: rate).stringValue, "observation_date": date.canonical]
        case let .contribution(action, id, fields):
            var patch: [String: Any] = [:]
            try Self.put(fields.amount, "amount", into: &patch) { $0.jsonObject }
            try Self.put(fields.date, "date", into: &patch) { $0.canonical }
            try Self.put(fields.fundingAccountID, "funding_account_id", into: &patch) { $0 }
            try Self.put(fields.fundingTransferID, "funding_transfer_id", into: &patch) { $0 }
            return ["type": "contribution", "action": action.rawValue, "designation_id": id, "fields": patch]
        case let .transfer(action, id, fields):
            var patch: [String: Any] = [:]
            try Self.put(fields.fromAccountID, "from_account_id", into: &patch) { $0 }
            try Self.put(fields.toAccountID, "to_account_id", into: &patch) { $0 }
            try Self.put(fields.received, "received", into: &patch) { $0.jsonObject }
            try Self.put(fields.date, "date", into: &patch) { $0.canonical }
            try Self.put(fields.fundingTransferID, "funding_transfer_id", into: &patch) { $0 }
            try Self.put(fields.requiredIndiaFunding, "required_india_funding", into: &patch) { $0.jsonObject }
            return ["type": "transfer", "action": action.rawValue, "transfer_id": id, "fields": patch]
        case let .investment(action, id, fields):
            var patch: [String: Any] = [:]
            try Self.put(fields.instrument, "instrument", into: &patch) { $0.jsonObject }
            try Self.put(fields.fundingAccountID, "funding_account_id", into: &patch) { $0 }
            try Self.put(fields.amount, "amount", into: &patch) { $0.jsonObject }
            try Self.put(fields.date, "date", into: &patch) { $0.canonical }
            try Self.put(fields.fundingTransferID, "funding_transfer_id", into: &patch) { $0 }
            return ["type": "investment", "action": action.rawValue, "investment_id": id, "fields": patch]
        case let .allocationLinks(fields):
            var patch: [String: Any] = [:]
            try Self.put(fields.requiredIndiaTransferID, "required_india_transfer_id", into: &patch) { $0 }
            try Self.put(fields.keepInCBQDesignationID, "keep_in_cbq_designation_id", into: &patch) { $0 }
            return ["type": "allocation_links", "fields": patch]
        case let .removeAllocation(kind, id):
            return ["type": "remove_allocation", "kind": kind.rawValue, "record_id": id]
        }
    }

    private static func put<T: Sendable>(_ patch: PlanningPatch<T>, _ key: String, into result: inout [String: Any], transform: (T) -> Any) throws {
        switch patch {
        case .omitted: break
        case .null: result[key] = NSNull()
        case .value(let value): result[key] = transform(value)
        }
    }
}

/// Exact C0 tool definition. Kept as a static value so protocol registration cannot drift.
nonisolated enum PlanningWriteToolSchema {
    static var toolDefinition: [String: Any] {
        get throws {
            guard let value = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
                throw PlanningChangeError.invalid("tool_schema")
            }
            return value
        }
    }

    private static let json = #"""
    {
  "name": "apply_planning_changes",
  "description": "Apply exact Budget Planning changes explicitly requested by the owner. Do not invoke merely because a recommendation was discussed. Changes are atomic and affect planning records only. Reuse request_id with identical arguments after an uncertain outcome.",
  "annotations": {
    "readOnlyHint": false,
    "destructiveHint": true,
    "idempotentHint": true,
    "openWorldHint": false
  },
  "inputSchema": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "request_id",
      "workspace_id",
      "month",
      "plan_id",
      "expected_write_revision",
      "changes"
    ],
    "properties": {
      "request_id": {
        "$ref": "#/$defs/uuid"
      },
      "workspace_id": {
        "$ref": "#/$defs/id"
      },
      "month": {
        "type": "string",
        "pattern": "^[0-9]{4}-(0[1-9]|1[0-2])$"
      },
      "plan_id": {
        "$ref": "#/$defs/id"
      },
      "expected_write_revision": {
        "type": "string",
        "pattern": "^planning-write-v1:[0-9a-f]{64}$"
      },
      "changes": {
        "type": "array",
        "minItems": 1,
        "maxItems": 32,
        "items": {
          "oneOf": [
            {
              "$ref": "#/$defs/monthlyAmount"
            },
            {
              "$ref": "#/$defs/deduction"
            },
            {
              "$ref": "#/$defs/obligation"
            },
            {
              "$ref": "#/$defs/balance"
            },
            {
              "$ref": "#/$defs/manualFX"
            },
            {
              "$ref": "#/$defs/contribution"
            },
            {
              "$ref": "#/$defs/transfer"
            },
            {
              "$ref": "#/$defs/investment"
            },
            {
              "$ref": "#/$defs/allocationLinks"
            },
            {
              "$ref": "#/$defs/removeAllocation"
            }
          ]
        }
      }
    },
    "$defs": {
      "id": {
        "type": "string",
        "minLength": 1,
        "maxLength": 128
      },
      "uuid": {
        "type": "string",
        "format": "uuid",
        "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
      },
      "nullableID": {
        "anyOf": [
          {
            "$ref": "#/$defs/id"
          },
          {
            "type": "null"
          }
        ]
      },
      "date": {
        "type": "string",
        "format": "date",
        "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
      },
      "nullableDate": {
        "anyOf": [
          {
            "$ref": "#/$defs/date"
          },
          {
            "type": "null"
          }
        ]
      },
      "money": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "currency",
          "decimal"
        ],
        "properties": {
          "currency": {
            "enum": [
              "QAR",
              "INR"
            ]
          },
          "decimal": {
            "type": "string",
            "maxLength": 21,
            "pattern": "^-?(0|[1-9][0-9]{0,16})\\.[0-9]{2}$"
          }
        }
      },
      "nullableMoney": {
        "anyOf": [
          {
            "$ref": "#/$defs/money"
          },
          {
            "type": "null"
          }
        ]
      },
      "instrument": {
        "oneOf": [
          {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "conid",
              "title",
              "quote_currency"
            ],
            "properties": {
              "kind": {
                "const": "ibkr"
              },
              "conid": {
                "type": "string",
                "minLength": 1,
                "maxLength": 64,
                "pattern": "^[0-9]+$"
              },
              "title": {
                "type": "string",
                "minLength": 1,
                "maxLength": 240
              },
              "quote_currency": {
                "type": "string",
                "pattern": "^[A-Z]{3}$"
              }
            }
          },
          {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "kind",
              "scheme_code",
              "title"
            ],
            "properties": {
              "kind": {
                "const": "indian_mutual_fund"
              },
              "scheme_code": {
                "type": "string",
                "minLength": 1,
                "maxLength": 64,
                "pattern": "^[0-9]+$"
              },
              "title": {
                "type": "string",
                "minLength": 1,
                "maxLength": 240
              }
            }
          }
        ]
      },
      "monthlyAmount": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "field",
          "amount"
        ],
        "properties": {
          "type": {
            "const": "monthly_amount"
          },
          "field": {
            "enum": [
              "expected_fixed",
              "expected_variable",
              "configured_transfer_fee",
              "keep_in_cbq"
            ]
          },
          "amount": {
            "$ref": "#/$defs/money"
          }
        }
      },
      "deduction": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "deduction_id",
          "amount"
        ],
        "properties": {
          "type": {
            "const": "deduction_amount"
          },
          "deduction_id": {
            "$ref": "#/$defs/id"
          },
          "amount": {
            "$ref": "#/$defs/money"
          }
        }
      },
      "obligation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "region",
          "obligation_id",
          "fields"
        ],
        "properties": {
          "type": {
            "const": "obligation"
          },
          "region": {
            "enum": [
              "qatar",
              "india"
            ]
          },
          "obligation_id": {
            "$ref": "#/$defs/id"
          },
          "fields": {
            "type": "object",
            "additionalProperties": false,
            "minProperties": 1,
            "properties": {
              "amount": {
                "$ref": "#/$defs/money"
              },
              "due_date": {
                "$ref": "#/$defs/nullableDate"
              },
              "included": {
                "type": "boolean"
              },
              "paying_account_id": {
                "$ref": "#/$defs/nullableID"
              }
            }
          }
        }
      },
      "balance": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "balance_id",
          "account_id",
          "fields"
        ],
        "properties": {
          "type": {
            "const": "planning_balance"
          },
          "balance_id": {
            "$ref": "#/$defs/id"
          },
          "account_id": {
            "$ref": "#/$defs/id"
          },
          "fields": {
            "type": "object",
            "additionalProperties": false,
            "minProperties": 1,
            "properties": {
              "amount": {
                "$ref": "#/$defs/money"
              },
              "included": {
                "type": "boolean"
              }
            }
          }
        }
      },
      "manualFX": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "inr_per_qar",
          "observation_date"
        ],
        "properties": {
          "type": {
            "const": "manual_fx"
          },
          "inr_per_qar": {
            "type": "string",
            "maxLength": 32,
            "pattern": "^(0|[1-9][0-9]*)(\\.[0-9]{1,28})?$"
          },
          "observation_date": {
            "$ref": "#/$defs/date"
          }
        }
      },
      "contributionFields": {
        "type": "object",
        "additionalProperties": false,
        "minProperties": 1,
        "properties": {
          "amount": {
            "$ref": "#/$defs/money"
          },
          "date": {
            "$ref": "#/$defs/date"
          },
          "funding_account_id": {
            "$ref": "#/$defs/id"
          },
          "funding_transfer_id": {
            "$ref": "#/$defs/nullableID"
          }
        }
      },
      "contribution": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "action",
          "designation_id",
          "fields"
        ],
        "properties": {
          "type": {
            "const": "contribution"
          },
          "action": {
            "enum": [
              "create",
              "update"
            ]
          },
          "designation_id": {
            "$ref": "#/$defs/id"
          },
          "fields": {
            "$ref": "#/$defs/contributionFields"
          }
        },
        "allOf": [
          {
            "if": {
              "properties": {
                "action": {
                  "const": "create"
                }
              }
            },
            "then": {
              "properties": {
                "fields": {
                  "required": [
                    "amount",
                    "date",
                    "funding_account_id",
                    "funding_transfer_id"
                  ]
                }
              }
            }
          }
        ]
      },
      "transferFields": {
        "type": "object",
        "additionalProperties": false,
        "minProperties": 1,
        "properties": {
          "from_account_id": {
            "$ref": "#/$defs/id"
          },
          "to_account_id": {
            "$ref": "#/$defs/id"
          },
          "received": {
            "$ref": "#/$defs/money"
          },
          "date": {
            "$ref": "#/$defs/date"
          },
          "funding_transfer_id": {
            "$ref": "#/$defs/nullableID"
          },
          "required_india_funding": {
            "$ref": "#/$defs/nullableMoney"
          }
        }
      },
      "transfer": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "action",
          "transfer_id",
          "fields"
        ],
        "properties": {
          "type": {
            "const": "transfer"
          },
          "action": {
            "enum": [
              "create",
              "update"
            ]
          },
          "transfer_id": {
            "$ref": "#/$defs/id"
          },
          "fields": {
            "$ref": "#/$defs/transferFields"
          }
        },
        "allOf": [
          {
            "if": {
              "properties": {
                "action": {
                  "const": "create"
                }
              }
            },
            "then": {
              "properties": {
                "transfer_id": {
                  "$ref": "#/$defs/uuid"
                },
                "fields": {
                  "required": [
                    "from_account_id",
                    "to_account_id",
                    "received",
                    "date",
                    "funding_transfer_id",
                    "required_india_funding"
                  ]
                }
              }
            }
          }
        ]
      },
      "investmentFields": {
        "type": "object",
        "additionalProperties": false,
        "minProperties": 1,
        "properties": {
          "instrument": {
            "$ref": "#/$defs/instrument"
          },
          "funding_account_id": {
            "$ref": "#/$defs/id"
          },
          "amount": {
            "$ref": "#/$defs/money"
          },
          "date": {
            "$ref": "#/$defs/date"
          },
          "funding_transfer_id": {
            "$ref": "#/$defs/nullableID"
          }
        }
      },
      "investment": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "action",
          "investment_id",
          "fields"
        ],
        "properties": {
          "type": {
            "const": "investment"
          },
          "action": {
            "enum": [
              "create",
              "update"
            ]
          },
          "investment_id": {
            "$ref": "#/$defs/id"
          },
          "fields": {
            "$ref": "#/$defs/investmentFields"
          }
        },
        "allOf": [
          {
            "if": {
              "properties": {
                "action": {
                  "const": "create"
                }
              }
            },
            "then": {
              "properties": {
                "investment_id": {
                  "$ref": "#/$defs/uuid"
                },
                "fields": {
                  "required": [
                    "instrument",
                    "funding_account_id",
                    "amount",
                    "date",
                    "funding_transfer_id"
                  ]
                }
              }
            }
          }
        ]
      },
      "allocationLinks": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "fields"
        ],
        "properties": {
          "type": {
            "const": "allocation_links"
          },
          "fields": {
            "type": "object",
            "additionalProperties": false,
            "minProperties": 1,
            "properties": {
              "required_india_transfer_id": {
                "$ref": "#/$defs/nullableID"
              },
              "keep_in_cbq_designation_id": {
                "$ref": "#/$defs/nullableID"
              }
            }
          }
        }
      },
      "removeAllocation": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type",
          "kind",
          "record_id"
        ],
        "properties": {
          "type": {
            "const": "remove_allocation"
          },
          "kind": {
            "enum": [
              "contribution",
              "transfer",
              "investment"
            ]
          },
          "record_id": {
            "$ref": "#/$defs/id"
          }
        }
      }
    }
  }
}
"""#
}

private nonisolated enum PlanningChangeParser {
    static func object(_ value: Any?, allowed: Set<String>, required: Set<String> = [], at path: String) throws -> [String: Any] {
        guard let value, let object = value as? [String: Any] else { throw PlanningChangeError.invalid(path) }
        if let key = object.keys.first(where: { !allowed.contains($0) }) { throw PlanningChangeError.unknownKey(path + "." + key) }
        if let key = required.first(where: { object[$0] == nil }) { throw PlanningChangeError.missing(path + "." + key) }
        return object
    }

    static func string(_ value: Any?, at path: String) throws -> String {
        guard let value = value as? String else { throw PlanningChangeError.invalid(path) }
        return value
    }

    static func id(_ value: Any?, at path: String) throws -> String {
        let value = try string(value, at: path)
        guard (1...128).contains(value.count), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanningChangeError.invalid(path)
        }
        return value
    }

    static func uuid(_ value: Any?, at path: String) throws -> String {
        let value = try string(value, at: path)
        guard value.range(of: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#, options: .regularExpression) != nil else {
            throw PlanningChangeError.invalid(path)
        }
        return value
    }

    static func month(_ value: Any?, at path: String) throws -> SelectedStatementMonth {
        let value = try string(value, at: path)
        guard let month = try? SelectedStatementMonth(canonical: value) else { throw PlanningChangeError.invalid(path) }
        return month
    }

    static func date(_ value: Any?, at path: String) throws -> StatementDate {
        let value = try string(value, at: path)
        guard let date = try? StatementDate(canonical: value) else { throw PlanningChangeError.invalid(path) }
        return date
    }

    static func boolean(_ value: Any?, at path: String) throws -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw PlanningChangeError.invalid(path)
        }
        return number.boolValue
    }

    static func money(_ value: Any?, at path: String) throws -> PlanningMoney {
        let object = try object(value, allowed: ["currency", "decimal"], required: ["currency", "decimal"], at: path)
        let currency = try string(object["currency"], at: path + ".currency")
        let decimal = try string(object["decimal"], at: path + ".decimal")
        guard ["QAR", "INR"].contains(currency), decimal.count <= 21,
              decimal.range(of: #"^-?(0|[1-9][0-9]{0,16})\.[0-9]{2}$"#, options: .regularExpression) != nil,
              let native = try? Money(canonicalDecimal: decimal, currency: currency),
              (try? native.canonicalDecimalString()) == decimal else {
            throw PlanningChangeError.invalid(path)
        }
        return PlanningMoney(money: native, decimal: decimal)
    }

    static func nonnegative(_ value: PlanningMoney, at path: String) throws -> PlanningMoney {
        guard value.money.amount >= .zero else { throw PlanningChangeError.invalid(path) }
        return value
    }

    static func currency(_ value: PlanningMoney, _ expected: String, at path: String) throws -> PlanningMoney {
        guard value.currency == expected else { throw PlanningChangeError.invalid(path + ".currency") }
        return value
    }

    static func enumValue<T: RawRepresentable>(_ value: Any?, as type: T.Type, at path: String) throws -> T where T.RawValue == String {
        let raw = try string(value, at: path)
        guard let result = T(rawValue: raw) else { throw PlanningChangeError.invalid(path) }
        return result
    }

    static func patch<T: Sendable>(_ object: [String: Any], _ key: String, at path: String,
                                   nullable: Bool = false, parse: (Any, String) throws -> T) throws -> PlanningPatch<T> {
        guard let raw = object[key] else { return .omitted }
        if raw is NSNull {
            guard nullable else { throw PlanningChangeError.invalid(path + "." + key) }
            return .null
        }
        return .value(try parse(raw, path + "." + key))
    }

    static func fields(_ value: Any?, allowed: Set<String>, required: Set<String> = [], at path: String) throws -> [String: Any] {
        let result = try object(value, allowed: allowed, required: required, at: path)
        guard !result.isEmpty else { throw PlanningChangeError.invalid(path) }
        return result
    }

    static func instrument(_ value: Any?, at path: String) throws -> PlanningInstrument {
        guard let object = value as? [String: Any] else { throw PlanningChangeError.invalid(path) }
        let kind = try string(object["kind"], at: path + ".kind")
        switch kind {
        case "ibkr":
            let item = try self.object(object, allowed: ["kind", "conid", "title", "quote_currency"],
                                       required: ["kind", "conid", "title", "quote_currency"], at: path)
            let conid = try digits(item["conid"], at: path + ".conid")
            let title = try nonblankTitle(item["title"], at: path + ".title")
            let quote = try string(item["quote_currency"], at: path + ".quote_currency")
            guard quote.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else { throw PlanningChangeError.invalid(path + ".quote_currency") }
            return .ibkr(conid: conid, title: title, quoteCurrency: quote)
        case "indian_mutual_fund":
            let item = try self.object(object, allowed: ["kind", "scheme_code", "title"],
                                       required: ["kind", "scheme_code", "title"], at: path)
            return .indianMutualFund(schemeCode: try digits(item["scheme_code"], at: path + ".scheme_code"),
                                     title: try nonblankTitle(item["title"], at: path + ".title"))
        default: throw PlanningChangeError.invalid(path + ".kind")
        }
    }

    private static func digits(_ value: Any?, at path: String) throws -> String {
        let text = try string(value, at: path)
        guard (1...64).contains(text.count), text.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              text.contains(where: { $0 != "0" }) else { throw PlanningChangeError.invalid(path) }
        return text
    }

    private static func nonblankTitle(_ value: Any?, at path: String) throws -> String {
        let text = try string(value, at: path)
        guard (1...240).contains(text.count), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanningChangeError.invalid(path)
        }
        return text
    }

    static func change(_ value: Any, at path: String) throws -> PlanningChange {
        guard let raw = value as? [String: Any] else { throw PlanningChangeError.invalid(path) }
        let type = try string(raw["type"], at: path + ".type")
        switch type {
        case "monthly_amount":
            let o = try object(raw, allowed: ["type", "field", "amount"], required: ["type", "field", "amount"], at: path)
            let field = try enumValue(o["field"], as: PlanningMonthlyField.self, at: path + ".field")
            let amount = try currency(money(o["amount"], at: path + ".amount"), "QAR", at: path + ".amount")
            if field == .configuredTransferFee || field == .keepInCBQ { _ = try nonnegative(amount, at: path + ".amount") }
            return .monthlyAmount(field: field, amount: amount)
        case "deduction_amount":
            let o = try object(raw, allowed: ["type", "deduction_id", "amount"], required: ["type", "deduction_id", "amount"], at: path)
            return .deductionAmount(deductionID: try id(o["deduction_id"], at: path + ".deduction_id"),
                                    amount: try nonnegative(currency(money(o["amount"], at: path + ".amount"), "QAR", at: path + ".amount"), at: path + ".amount"))
        case "obligation":
            let o = try object(raw, allowed: ["type", "region", "obligation_id", "fields"], required: ["type", "region", "obligation_id", "fields"], at: path)
            let f = try fields(o["fields"], allowed: ["amount", "due_date", "included", "paying_account_id"], at: path + ".fields")
            let region = try enumValue(o["region"], as: PlanningRegion.self, at: path + ".region")
            return .obligation(region: region,
                               obligationID: try id(o["obligation_id"], at: path + ".obligation_id"),
                               fields: PlanningObligationFields(
                                amount: try patch(f, "amount", at: path + ".fields") { try nonnegative(currency(money($0, at: $1), region == .qatar ? "QAR" : "INR", at: $1), at: $1) },
                                dueDate: try patch(f, "due_date", at: path + ".fields", nullable: true, parse: date),
                                included: try patch(f, "included", at: path + ".fields", parse: boolean),
                                payingAccountID: try patch(f, "paying_account_id", at: path + ".fields", nullable: true, parse: id)))
        case "planning_balance":
            let o = try object(raw, allowed: ["type", "balance_id", "account_id", "fields"], required: ["type", "balance_id", "account_id", "fields"], at: path)
            let f = try fields(o["fields"], allowed: ["amount", "included"], at: path + ".fields")
            return .planningBalance(balanceID: try id(o["balance_id"], at: path + ".balance_id"),
                                    accountID: try id(o["account_id"], at: path + ".account_id"),
                                    fields: PlanningBalanceFields(amount: try patch(f, "amount", at: path + ".fields", parse: money),
                                                                  included: try patch(f, "included", at: path + ".fields", parse: boolean)))
        case "manual_fx":
            let o = try object(raw, allowed: ["type", "inr_per_qar", "observation_date"], required: ["type", "inr_per_qar", "observation_date"], at: path)
            let lexical = try string(o["inr_per_qar"], at: path + ".inr_per_qar")
            guard lexical.count <= 32,
                  lexical.range(of: #"^(0|[1-9][0-9]*)(\.[0-9]{1,28})?$"#, options: .regularExpression) != nil,
                  let rate = Decimal(string: lexical, locale: Locale(identifier: "en_US_POSIX")), rate > .zero else {
                throw PlanningChangeError.invalid(path + ".inr_per_qar")
            }
            return .manualFX(inrPerQAR: rate, observationDate: try date(o["observation_date"], at: path + ".observation_date"))
        case "contribution":
            let o = try object(raw, allowed: ["type", "action", "designation_id", "fields"], required: ["type", "action", "designation_id", "fields"], at: path)
            let action = try enumValue(o["action"], as: PlanningAllocationAction.self, at: path + ".action")
            let f = try fields(o["fields"], allowed: ["amount", "date", "funding_account_id", "funding_transfer_id"],
                               required: action == .create ? ["amount", "date", "funding_account_id", "funding_transfer_id"] : [], at: path + ".fields")
            return .contribution(action: action, designationID: try id(o["designation_id"], at: path + ".designation_id"),
                                 fields: PlanningContributionFields(
                                    amount: try patch(f, "amount", at: path + ".fields") { try nonnegative(money($0, at: $1), at: $1) },
                                    date: try patch(f, "date", at: path + ".fields", parse: date),
                                    fundingAccountID: try patch(f, "funding_account_id", at: path + ".fields", parse: id),
                                    fundingTransferID: try patch(f, "funding_transfer_id", at: path + ".fields", nullable: true, parse: id)))
        case "transfer":
            let o = try object(raw, allowed: ["type", "action", "transfer_id", "fields"], required: ["type", "action", "transfer_id", "fields"], at: path)
            let action = try enumValue(o["action"], as: PlanningAllocationAction.self, at: path + ".action")
            let f = try fields(o["fields"], allowed: ["from_account_id", "to_account_id", "received", "date", "funding_transfer_id", "required_india_funding"],
                               required: action == .create ? ["from_account_id", "to_account_id", "received", "date", "funding_transfer_id", "required_india_funding"] : [], at: path + ".fields")
            let transferID = try (action == .create ? uuid(o["transfer_id"], at: path + ".transfer_id") : id(o["transfer_id"], at: path + ".transfer_id"))
            return .transfer(action: action, transferID: transferID, fields: PlanningTransferFields(
                fromAccountID: try patch(f, "from_account_id", at: path + ".fields", parse: id),
                toAccountID: try patch(f, "to_account_id", at: path + ".fields", parse: id),
                received: try patch(f, "received", at: path + ".fields") { try nonnegative(money($0, at: $1), at: $1) },
                date: try patch(f, "date", at: path + ".fields", parse: date),
                fundingTransferID: try patch(f, "funding_transfer_id", at: path + ".fields", nullable: true, parse: id),
                requiredIndiaFunding: try patch(f, "required_india_funding", at: path + ".fields", nullable: true) { try nonnegative(currency(money($0, at: $1), "INR", at: $1), at: $1) }))
        case "investment":
            let o = try object(raw, allowed: ["type", "action", "investment_id", "fields"], required: ["type", "action", "investment_id", "fields"], at: path)
            let action = try enumValue(o["action"], as: PlanningAllocationAction.self, at: path + ".action")
            let f = try fields(o["fields"], allowed: ["instrument", "funding_account_id", "amount", "date", "funding_transfer_id"],
                               required: action == .create ? ["instrument", "funding_account_id", "amount", "date", "funding_transfer_id"] : [], at: path + ".fields")
            let investmentID = try (action == .create ? uuid(o["investment_id"], at: path + ".investment_id") : id(o["investment_id"], at: path + ".investment_id"))
            return .investment(action: action, investmentID: investmentID, fields: PlanningInvestmentFields(
                instrument: try patch(f, "instrument", at: path + ".fields", parse: instrument),
                fundingAccountID: try patch(f, "funding_account_id", at: path + ".fields", parse: id),
                amount: try patch(f, "amount", at: path + ".fields") { try nonnegative(money($0, at: $1), at: $1) },
                date: try patch(f, "date", at: path + ".fields", parse: date),
                fundingTransferID: try patch(f, "funding_transfer_id", at: path + ".fields", nullable: true, parse: id)))
        case "allocation_links":
            let o = try object(raw, allowed: ["type", "fields"], required: ["type", "fields"], at: path)
            let f = try fields(o["fields"], allowed: ["required_india_transfer_id", "keep_in_cbq_designation_id"], at: path + ".fields")
            return .allocationLinks(fields: PlanningAllocationLinksFields(
                requiredIndiaTransferID: try patch(f, "required_india_transfer_id", at: path + ".fields", nullable: true, parse: id),
                keepInCBQDesignationID: try patch(f, "keep_in_cbq_designation_id", at: path + ".fields", nullable: true, parse: id)))
        case "remove_allocation":
            let o = try object(raw, allowed: ["type", "kind", "record_id"], required: ["type", "kind", "record_id"], at: path)
            return .removeAllocation(kind: try enumValue(o["kind"], as: PlanningAllocationKind.self, at: path + ".kind"),
                                     recordID: try id(o["record_id"], at: path + ".record_id"))
        default: throw PlanningChangeError.invalid(path + ".type")
        }
    }

    static func checkDuplicateAssignments(_ changes: [PlanningChange]) throws {
        var assigned = Set<String>()
        var rowOperations: [String: RowOperation] = [:]
        for change in changes {
            let (row, action, keys) = assignmentInfo(change)
            if let row {
                let operation: RowOperation = switch action {
                case .create: .create
                case .update: .update
                case nil: .remove
                }
                if let previous = rowOperations[row] {
                    if previous != .update || operation != .update { throw PlanningChangeError.conflictingRow(row) }
                } else { rowOperations[row] = operation }
            }
            for key in keys where !assigned.insert(key).inserted { throw PlanningChangeError.duplicateAssignment(key) }
        }
    }

    private enum RowOperation { case create, update, remove }

    private static func assignmentInfo(_ change: PlanningChange) -> (String?, PlanningAllocationAction?, [String]) {
        func keys(_ root: String, _ fields: [String: Bool]) -> [String] { fields.filter { $0.value }.map { root + "." + $0.key } }
        switch change {
        case let .monthlyAmount(field, _): return (nil, nil, ["monthly." + field.rawValue])
        case let .deductionAmount(id, _): return (nil, nil, ["deduction." + id + ".amount"])
        case let .obligation(region, id, f):
            return (nil, nil, keys("obligation." + region.rawValue + "." + id, ["amount": f.amount.isSupplied, "due_date": f.dueDate.isSupplied, "included": f.included.isSupplied, "paying_account_id": f.payingAccountID.isSupplied]))
        case let .planningBalance(id, _, f):
            return (nil, nil, keys("balance." + id, ["amount": f.amount.isSupplied, "included": f.included.isSupplied]))
        case .manualFX: return (nil, nil, ["manual_fx"])
        case let .contribution(action, id, f):
            let row = "contribution." + id
            return (row, action, keys(row, ["amount": f.amount.isSupplied, "date": f.date.isSupplied, "funding_account_id": f.fundingAccountID.isSupplied, "funding_transfer_id": f.fundingTransferID.isSupplied]))
        case let .transfer(action, id, f):
            let row = "transfer." + id
            return (row, action, keys(row, ["from_account_id": f.fromAccountID.isSupplied, "to_account_id": f.toAccountID.isSupplied, "received": f.received.isSupplied, "date": f.date.isSupplied, "funding_transfer_id": f.fundingTransferID.isSupplied, "required_india_funding": f.requiredIndiaFunding.isSupplied]))
        case let .investment(action, id, f):
            let row = "investment." + id
            return (row, action, keys(row, ["instrument": f.instrument.isSupplied, "funding_account_id": f.fundingAccountID.isSupplied, "amount": f.amount.isSupplied, "date": f.date.isSupplied, "funding_transfer_id": f.fundingTransferID.isSupplied]))
        case let .allocationLinks(f):
            return (nil, nil, keys("allocation_links", ["required_india_transfer_id": f.requiredIndiaTransferID.isSupplied, "keep_in_cbq_designation_id": f.keepInCBQDesignationID.isSupplied]))
        case let .removeAllocation(kind, id): return (kind.rawValue + "." + id, nil, ["remove." + kind.rawValue + "." + id])
        }
    }
}
