// Alignment test component with nested records

use alignment_component_bindings::exports::test::alignment::alignment_test::{
    Guest, Point, NestedData, ComplexNested
};

struct Component;

impl Guest for Component {
    fn test_simple(p: Point) -> Point {
        // Echo back the point, testing alignment of float64 fields
        eprintln!("test_simple: x={}, y={}", p.x, p.y);
        Point {
            x: p.x * 2.0,
            y: p.y * 2.0,
        }
    }

    fn test_nested(data: NestedData) -> NestedData {
        // Test nested structure alignment
        eprintln!("test_nested: id={}, name={}, location=({}, {}), active={}",
                  data.id, data.name, data.location.x, data.location.y, data.active);

        NestedData {
            id: data.id + 1,
            name: format!("Processed: {}", data.name),
            location: Point {
                x: data.location.x + 1.0,
                y: data.location.y + 1.0,
            },
            active: !data.active,
        }
    }

    fn test_complex(data: ComplexNested) -> ComplexNested {
        // Test complex nested structure with deep nesting
        eprintln!("test_complex: header.id={}, count={}, metadata.len={}, flag={}",
                  data.header.id, data.count, data.metadata.len(), data.flag);

        let mut new_metadata = data.metadata.clone();
        new_metadata.push(NestedData {
            id: 999,
            name: "Added item".to_string(),
            location: Point { x: 0.0, y: 0.0 },
            active: true,
        });

        ComplexNested {
            header: NestedData {
                id: data.header.id + 100,
                name: data.header.name.clone(),
                location: data.header.location.clone(),
                active: data.header.active,
            },
            count: data.count + 1,
            metadata: new_metadata,
            flag: !data.flag,
        }
    }

    fn test_list(items: Vec<NestedData>) -> Vec<NestedData> {
        // Test list of nested structures
        eprintln!("test_list: processing {} items", items.len());

        items.into_iter().map(|item| {
            NestedData {
                id: item.id * 2,
                name: item.name.to_uppercase(),
                location: Point {
                    x: item.location.x / 2.0,
                    y: item.location.y / 2.0,
                },
                active: item.active,
            }
        }).collect()
    }
}

alignment_component_bindings::export!(Component with_types_in alignment_component_bindings);
