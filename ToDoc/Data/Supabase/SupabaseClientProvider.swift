//
//  SupabaseClientProvider.swift
//  ToDoc
//
//  Created by 앤디 on 10/11/26.
//

import Supabase

final class SupabaseClientProvider {
    let client: SupabaseClient
    
    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }
}
