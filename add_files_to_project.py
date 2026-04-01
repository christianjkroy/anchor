#!/usr/bin/env python3
"""
Adds all new Anchor source files to the Xcode project (.pbxproj).
Run once from the repo root: python3 add_files_to_project.py
"""

import re
import sys

PBXPROJ = "Anchor/Anchor.xcodeproj/project.pbxproj"

# -----------------------------------------------------------------------
# New files to add: (file_path_relative_to_Anchor_folder, group_key, file_type)
# -----------------------------------------------------------------------
NEW_FILES = [
    # Services/Claude
    ("Services/Claude/ClaudeModels.swift",        "SERVICES_CLAUDE",   "sourcecode.swift"),
    ("Services/Claude/ClaudePrompts.swift",        "SERVICES_CLAUDE",   "sourcecode.swift"),
    ("Services/Claude/ClaudeService.swift",        "SERVICES_CLAUDE",   "sourcecode.swift"),
    # Services/Notifications
    ("Services/Notifications/DigestNotificationService.swift", "SERVICES_NOTIF", "sourcecode.swift"),
    # Services/Supabase
    ("Services/Supabase/EncryptionService.swift",  "SERVICES_SUPA",     "sourcecode.swift"),
    ("Services/Supabase/SupabaseModels.swift",     "SERVICES_SUPA",     "sourcecode.swift"),
    ("Services/Supabase/SupabaseService.swift",    "SERVICES_SUPA",     "sourcecode.swift"),
    # Models
    ("Models/Pattern.swift",                       "MODELS",            "sourcecode.swift"),
    ("Models/WeeklyDigest.swift",                  "MODELS",            "sourcecode.swift"),
    # Views/Components
    ("Views/Components/SentimentBadge.swift",      "COMPONENTS",        "sourcecode.swift"),
    ("Views/Components/SentimentDistributionBar.swift", "COMPONENTS",   "sourcecode.swift"),
    ("Views/Components/HapticFeedback.swift",      "COMPONENTS",        "sourcecode.swift"),
    # Views/Graph
    ("Views/Graph/GraphViewModel.swift",           "GRAPH",             "sourcecode.swift"),
    ("Views/Graph/RelationshipGraphView.swift",    "GRAPH",             "sourcecode.swift"),
    # Views/Graph/Metal
    ("Views/Graph/Metal/ForceSimulation.swift",    "GRAPH_METAL",       "sourcecode.swift"),
    ("Views/Graph/Metal/GraphRenderer.swift",      "GRAPH_METAL",       "sourcecode.swift"),
    ("Views/Graph/Metal/GraphShaders.metal",       "GRAPH_METAL",       "sourcecode.metal"),
    # Views/Digests
    ("Views/Digests/DigestListView.swift",         "DIGESTS",           "sourcecode.swift"),
    ("Views/Digests/DigestDetailView.swift",       "DIGESTS",           "sourcecode.swift"),
    # Views/Onboarding
    ("Views/Onboarding/OnboardingView.swift",      "ONBOARDING",        "sourcecode.swift"),
    # Views/Settings
    ("Views/Settings/SettingsView.swift",          "SETTINGS",          "sourcecode.swift"),
]

# ID counters — start well above existing IDs to avoid collisions
_file_ref_counter = 0x200
_build_file_counter = 0x200
_group_counter = 0xB00

def make_file_ref_id():
    global _file_ref_counter
    _file_ref_counter += 1
    return f"AA{_file_ref_counter:04X}000000000000000000"[:24]

def make_build_file_id():
    global _build_file_counter
    _build_file_counter += 1
    return f"AB{_build_file_counter:04X}000000000000000000"[:24]

def make_group_id():
    global _group_counter
    _group_counter += 1
    return f"AC{_group_counter:04X}000000000000000000"[:24]


def main():
    with open(PBXPROJ, "r") as f:
        content = f.read()

    # -----------------------------------------------------------------------
    # Map group keys -> existing group IDs in the pbxproj
    # -----------------------------------------------------------------------
    existing_groups = {
        "MODELS":     "AC0000040000000000000000",
        "COMPONENTS": "AC0000060000000000000000",
        "GRAPH":      "AC0000090000000000000000",
    }

    # New groups we need to create (key -> (name, path, parent_group_id))
    new_groups_to_create = {
        "SERVICES":       ("Services",      "Services",      "AC0000030000000000000000"),  # parent = Anchor root
        "SERVICES_CLAUDE":("Claude",        "Claude",        None),   # parent = SERVICES
        "SERVICES_NOTIF": ("Notifications", "Notifications", None),   # parent = SERVICES
        "SERVICES_SUPA":  ("Supabase",      "Supabase",      None),   # parent = SERVICES
        "GRAPH_METAL":    ("Metal",         "Metal",         "AC0000090000000000000000"),  # parent = GRAPH
        "DIGESTS":        ("Digests",       "Digests",       "AC0000050000000000000000"),  # parent = Views
        "ONBOARDING":     ("Onboarding",    "Onboarding",    "AC0000050000000000000000"),
        "SETTINGS":       ("Settings",      "Settings",      "AC0000050000000000000000"),
    }

    # Assign IDs to new groups
    group_ids = dict(existing_groups)
    for key in new_groups_to_create:
        group_ids[key] = make_group_id()

    # Fix nested parents
    new_groups_to_create["SERVICES_CLAUDE"] = (new_groups_to_create["SERVICES_CLAUDE"][0], new_groups_to_create["SERVICES_CLAUDE"][1], group_ids["SERVICES"])
    new_groups_to_create["SERVICES_NOTIF"] = (new_groups_to_create["SERVICES_NOTIF"][0], new_groups_to_create["SERVICES_NOTIF"][1], group_ids["SERVICES"])
    new_groups_to_create["SERVICES_SUPA"] = (new_groups_to_create["SERVICES_SUPA"][0], new_groups_to_create["SERVICES_SUPA"][1], group_ids["SERVICES"])

    # -----------------------------------------------------------------------
    # Generate entries for each file
    # -----------------------------------------------------------------------
    build_file_entries = []
    file_ref_entries = []
    source_build_phase_entries = []
    group_file_map = {}  # group_key -> [(file_ref_id, filename)]

    for (fpath, group_key, ftype) in NEW_FILES:
        filename = fpath.split("/")[-1]
        fref_id = make_file_ref_id()
        bfile_id = make_build_file_id()

        file_ref_entries.append(
            f'\t\t{fref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {filename}; sourceTree = "<group>"; }};'
        )
        build_file_entries.append(
            f'\t\t{bfile_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref_id} /* {filename} */; }};'
        )
        if ftype != "sourcecode.metal":
            source_build_phase_entries.append(
                f'\t\t\t\t{bfile_id} /* {filename} in Sources */,'
            )
        else:
            # Metal files go in Sources too
            source_build_phase_entries.append(
                f'\t\t\t\t{bfile_id} /* {filename} in Sources */,'
            )

        if group_key not in group_file_map:
            group_file_map[group_key] = []
        group_file_map[group_key].append((fref_id, filename))

    # -----------------------------------------------------------------------
    # 1. Insert build file entries after "/* Begin PBXBuildFile section */"
    # -----------------------------------------------------------------------
    build_section_marker = "/* Begin PBXBuildFile section */"
    insert_after = content.index(build_section_marker) + len(build_section_marker)
    build_insert = "\n" + "\n".join(build_file_entries)
    content = content[:insert_after] + build_insert + content[insert_after:]

    # -----------------------------------------------------------------------
    # 2. Insert file reference entries after "/* Begin PBXFileReference section */"
    # -----------------------------------------------------------------------
    ref_section_marker = "/* Begin PBXFileReference section */"
    insert_after = content.index(ref_section_marker) + len(ref_section_marker)
    ref_insert = "\n" + "\n".join(file_ref_entries)
    content = content[:insert_after] + ref_insert + content[insert_after:]

    # -----------------------------------------------------------------------
    # 3. Insert source build phase entries before "/* End PBXSourcesBuildPhase section */"
    # -----------------------------------------------------------------------
    end_sources_marker = "/* End PBXSourcesBuildPhase section */"
    # Find last ); before the end marker
    idx = content.index(end_sources_marker)
    # Find the ); before this
    close_paren_idx = content.rfind(");", 0, idx)
    sources_insert = "\n" + "\n".join(source_build_phase_entries) + "\n"
    content = content[:close_paren_idx] + sources_insert + "\t\t\t" + content[close_paren_idx:]

    # -----------------------------------------------------------------------
    # 4. Add files to existing groups
    # -----------------------------------------------------------------------
    for group_key, files in group_file_map.items():
        if group_key not in existing_groups:
            continue
        gid = existing_groups[group_key]
        # Find the group and insert file refs into its children list
        # Pattern: look for the group id, then find "children = (" and add before ");"
        pattern = re.compile(
            r'(' + re.escape(gid) + r'.*?children\s*=\s*\()([^;]*?)(\);)',
            re.DOTALL
        )
        def make_replacer(files):
            def replacer(m):
                new_children = "\n".join(f"\t\t\t\t{fref_id} /* {fname} */," for fref_id, fname in files)
                return m.group(1) + m.group(2) + "\t\t\t\t" + new_children + "\n\t\t\t" + m.group(3)
            return replacer
        content = pattern.sub(make_replacer(files), content, count=1)

    # -----------------------------------------------------------------------
    # 5. Create new groups and insert them
    # -----------------------------------------------------------------------
    # Build group definitions
    group_definitions = []
    children_to_add_to_parent = {}  # parent_group_id -> [child_group_id]

    for key, (name, path, parent_id) in new_groups_to_create.items():
        gid = group_ids[key]
        child_refs = group_file_map.get(key, [])
        children_str = "\n".join(f"\t\t\t\t{fref_id} /* {fname} */," for fref_id, fname in child_refs)

        # Add sub-groups as children if they exist
        for subkey, (_, _, sub_parent) in new_groups_to_create.items():
            if sub_parent == gid:
                children_str += f"\n\t\t\t\t{group_ids[subkey]} /* {new_groups_to_create[subkey][0]} */,"

        group_def = f"""
\t\t{gid} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{children_str}
\t\t\t);
\t\t\tpath = {path};
\t\t\tsourceTree = "<group>";
\t\t}};"""
        group_definitions.append(group_def)

        if parent_id:
            if parent_id not in children_to_add_to_parent:
                children_to_add_to_parent[parent_id] = []
            children_to_add_to_parent[parent_id].append((gid, name))

    # Insert group definitions before "/* End PBXGroup section */"
    end_group_marker = "/* End PBXGroup section */"
    idx = content.index(end_group_marker)
    groups_insert = "\n".join(group_definitions) + "\n"
    content = content[:idx] + groups_insert + content[idx:]

    # -----------------------------------------------------------------------
    # 6. Add new top-level groups to their parent groups
    # -----------------------------------------------------------------------
    for parent_id, children in children_to_add_to_parent.items():
        # Skip if parent is one of the new groups (already handled above)
        if parent_id in group_ids.values() and parent_id not in existing_groups.values():
            continue
        pattern = re.compile(
            r'(' + re.escape(parent_id) + r'.*?children\s*=\s*\()([^;]*?)(\);)',
            re.DOTALL
        )
        def make_group_replacer(children):
            def replacer(m):
                new_children = "\n".join(f"\t\t\t\t{gid} /* {name} */," for gid, name in children)
                return m.group(1) + m.group(2) + "\t\t\t\t" + new_children + "\n\t\t\t" + m.group(3)
            return replacer
        content = pattern.sub(make_group_replacer(children), content, count=1)

    # -----------------------------------------------------------------------
    # Write output
    # -----------------------------------------------------------------------
    with open(PBXPROJ, "w") as f:
        f.write(content)

    print(f"✓ Added {len(NEW_FILES)} files to {PBXPROJ}")
    print("  Open Xcode — all files should appear in the Project Navigator.")


if __name__ == "__main__":
    main()
